import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "packages" / "node-red-file-mcp.py"
SPEC = importlib.util.spec_from_file_location("node_red_file_mcp", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
mcp = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mcp)


class NodeRedFileMcpTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        os.environ["XDG_RUNTIME_DIR"] = self.tempdir.name

    def write_flow(self, filename, data):
        root = Path(self.tempdir.name) / "hermes-node-red"
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        path = root / filename
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    @staticmethod
    def result_payload(result):
        return json.loads(result["content"][0]["text"])

    def test_rejects_duplicate_ids_across_flow_nodes_and_configs(self):
        errors = mcp.validate_flow_data(
            {
                "id": "flow-1",
                "nodes": [{"id": "node-1", "type": "inject"}],
                "configs": [{"id": "node-1", "type": "server-config"}],
            }
        )
        self.assertTrue(any("duplicates id" in error for error in errors))

    def test_rejects_node_without_type(self):
        errors = mcp.validate_flow_data(
            {"id": "flow-1", "nodes": [{"id": "node-1"}]}
        )
        self.assertIn("Node node-1 missing required type field", errors)

    def test_rejects_path_traversal(self):
        with self.assertRaises(ValueError):
            mcp.resolve_flow_file("../flow.json")

    def test_update_rejects_flow_id_mismatch_before_network(self):
        self.write_flow(
            "flow.json",
            {"id": "flow-a", "nodes": [{"id": "node-1", "type": "inject"}]},
        )

        original_request = mcp.node_red_request
        self.addCleanup(setattr, mcp, "node_red_request", original_request)

        def fail_if_called(*_args, **_kwargs):
            raise AssertionError("network request must not run for mismatched flow ids")

        mcp.node_red_request = fail_if_called
        result = mcp.call_tool(
            "update_flow_file", {"flowId": "flow-b", "filename": "flow.json"}
        )
        payload = self.result_payload(result)

        self.assertTrue(result.get("isError"))
        self.assertFalse(payload["updated"])
        self.assertIn("Flow id mismatch", payload["errors"][0])

    def test_valid_update_deploys_exact_complete_flow(self):
        flow = {
            "id": "flow-a",
            "label": "Example",
            "nodes": [{"id": "node-1", "type": "inject"}],
            "configs": [{"id": "config-1", "type": "server-config"}],
        }
        self.write_flow("flow.json", flow)

        captured = {}
        original_request = mcp.node_red_request
        self.addCleanup(setattr, mcp, "node_red_request", original_request)

        def capture_request(flow_id, data):
            captured["flow_id"] = flow_id
            captured["data"] = data
            return {"id": flow_id, "status": 200}

        mcp.node_red_request = capture_request
        result = mcp.call_tool(
            "update_flow_file", {"flowId": "flow-a", "filename": "flow.json"}
        )
        payload = self.result_payload(result)

        self.assertFalse(result.get("isError", False))
        self.assertTrue(payload["updated"])
        self.assertEqual(captured["flow_id"], "flow-a")
        self.assertEqual(captured["data"], flow)


if __name__ == "__main__":
    unittest.main()
