"""
Quadlet and Kubernetes Pod Manifest Schema Validation Module.
Validates generated Quadlet `.kube` and `.yaml` Kubernetes Pod manifests
against Podman 5+ specifications using YAML parsing.
"""

import configparser
import unittest
import yaml


class QuadletKubeValidator:
    """Validates Podman 5+ Quadlet .kube unit file schemas."""

    @staticmethod
    def parse_kube_unit(content: str) -> configparser.ConfigParser:
        config = configparser.ConfigParser(interpolation=None, dict_type=dict)
        # Quadlet file keys are case-sensitive (e.g., Yaml=)
        config.optionxform = str
        config.read_string(content)
        return config

    @classmethod
    def validate_kube_content(cls, content: str) -> dict:
        errors = []
        try:
            config = cls.parse_kube_unit(content)
        except Exception as e:
            return {"valid": False, "errors": [f"INI parsing error: {e}"]}

        if "Kube" not in config:
            errors.append("Missing required [Kube] section")
        else:
            kube_sec = config["Kube"]
            if "Yaml" not in kube_sec:
                errors.append("Missing Yaml key in [Kube] section")
            elif not isinstance(kube_sec.get("Yaml"), str) or not kube_sec.get("Yaml", "").strip():
                errors.append("Yaml key in [Kube] section must be a non-empty string")

        return {"valid": len(errors) == 0, "errors": errors}


class KubernetesPodValidator:
    """Validates Kubernetes Pod manifest schemas (.yaml) used by Podman 5+ Quadlet Kube."""

    @classmethod
    def validate_pod_content(cls, content: str) -> dict:
        errors = []
        try:
            data = yaml.safe_load(content)
        except Exception as e:
            return {"valid": False, "errors": [f"YAML parsing error: {e}"]}

        if not isinstance(data, dict):
            return {"valid": False, "errors": ["Root of YAML manifest must be a dictionary"]}

        if data.get("apiVersion") != "v1":
            errors.append("apiVersion must be 'v1'")

        if data.get("kind") != "Pod":
            errors.append("kind must be 'Pod'")

        metadata = data.get("metadata")
        if not isinstance(metadata, dict):
            errors.append("metadata must be a dictionary")
        else:
            name_val = metadata.get("name")
            if not isinstance(name_val, str) or not name_val.strip():
                errors.append("metadata.name must be a non-empty string containing non-whitespace characters")

        spec = data.get("spec")
        if not isinstance(spec, dict):
            errors.append("spec section must be a dictionary")
        else:
            containers = spec.get("containers")
            if not isinstance(containers, list) or len(containers) == 0:
                errors.append("spec.containers must be a non-empty list")
            else:
                for idx, c in enumerate(containers):
                    if not isinstance(c, dict):
                        errors.append(f"spec.containers[{idx}] must be a dictionary")
                        continue
                    c_name = c.get("name")
                    if not isinstance(c_name, str) or not c_name.strip():
                        errors.append(f"Container at index {idx} 'name' must be a non-empty string containing non-whitespace characters")
                    c_image = c.get("image")
                    if not isinstance(c_image, str) or not c_image.strip():
                        errors.append(f"Container at index {idx} 'image' must be a non-empty string containing non-whitespace characters")

        return {"valid": len(errors) == 0, "errors": errors}


class TestContainerManifestSchemas(unittest.TestCase):
    """Unit tests for Quadlet .kube and Pod .yaml schema validation."""

    def test_sample_quadlet_kube_validation(self):
        valid_kube = (
            "[Unit]\n"
            "Description=Sovereign Stack (Quadlet Kube)\n\n"
            "[Kube]\n"
            "Yaml=stack.yaml\n\n"
            "[Install]\n"
            "WantedBy=default.target\n"
        )
        result = QuadletKubeValidator.validate_kube_content(valid_kube)
        self.assertTrue(result["valid"], f"Validation failed with errors: {result['errors']}")

    def test_minimal_valid_quadlet_kube(self):
        minimal_kube = (
            "[Kube]\n"
            "Yaml=stack.yaml\n"
        )
        result = QuadletKubeValidator.validate_kube_content(minimal_kube)
        self.assertTrue(result["valid"], f"Validation failed for minimal Quadlet: {result['errors']}")

    def test_invalid_quadlet_kube_missing_kube_section(self):
        invalid_kube = (
            "[Unit]\n"
            "Description=Missing Kube Section\n"
        )
        result = QuadletKubeValidator.validate_kube_content(invalid_kube)
        self.assertFalse(result["valid"])
        self.assertIn("Missing required [Kube] section", result["errors"])

    def test_invalid_quadlet_kube_empty_yaml(self):
        empty_yaml_kube = (
            "[Kube]\n"
            "Yaml=\n"
        )
        result = QuadletKubeValidator.validate_kube_content(empty_yaml_kube)
        self.assertFalse(result["valid"])
        self.assertIn("Yaml key in [Kube] section must be a non-empty string", result["errors"])

    def test_sample_pod_yaml_validation(self):
        valid_yaml = (
            "apiVersion: v1\n"
            "kind: Pod\n"
            "metadata:\n"
            "  name: test-pod\n"
            "spec:\n"
            "  containers:\n"
            "    - name: app\n"
            "      image: docker.io/library/alpine:latest\n"
        )
        result = KubernetesPodValidator.validate_pod_content(valid_yaml)
        self.assertTrue(result["valid"], f"Validation failed with errors: {result['errors']}")

    def test_invalid_pod_yaml_schema(self):
        invalid_yaml = (
            "apiVersion: v2\n"
            "kind: Deployment\n"
        )
        result = KubernetesPodValidator.validate_pod_content(invalid_yaml)
        self.assertFalse(result["valid"])
        self.assertIn("apiVersion must be 'v1'", result["errors"])
        self.assertIn("kind must be 'Pod'", result["errors"])

    def test_invalid_pod_yaml_malformed_syntax(self):
        malformed_yaml = "apiVersion: v1\nkind: Pod\n  metadata: [unbalanced"
        result = KubernetesPodValidator.validate_pod_content(malformed_yaml)
        self.assertFalse(result["valid"])
        self.assertTrue(any("YAML parsing error" in err for err in result["errors"]))

    def test_invalid_pod_yaml_top_level_misplaced_fields(self):
        misplaced_yaml = (
            "apiVersion: v1\n"
            "kind: Pod\n"
            "name: top-level-name\n"
            "containers:\n"
            "  - name: app\n"
            "    image: alpine\n"
        )
        result = KubernetesPodValidator.validate_pod_content(misplaced_yaml)
        self.assertFalse(result["valid"])
        self.assertIn("metadata must be a dictionary", result["errors"])
        self.assertIn("spec section must be a dictionary", result["errors"])

    def test_invalid_pod_non_string_or_whitespace_fields(self):
        # Test boolean, numeric, empty, and whitespace-only values for metadata.name and container name/image
        cases = [
            ("metadata.name boolean", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: true\nspec:\n  containers:\n    - name: app\n      image: alpine\n", "metadata.name must be a non-empty string"),
            ("metadata.name numeric", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: 12345\nspec:\n  containers:\n    - name: app\n      image: alpine\n", "metadata.name must be a non-empty string"),
            ("metadata.name whitespace", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: '   '\nspec:\n  containers:\n    - name: app\n      image: alpine\n", "metadata.name must be a non-empty string"),
            ("container.name boolean", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: true\n      image: alpine\n", "Container at index 0 'name' must be a non-empty string"),
            ("container.name numeric", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: 999\n      image: alpine\n", "Container at index 0 'name' must be a non-empty string"),
            ("container.name whitespace", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: '  '\n      image: alpine\n", "Container at index 0 'name' must be a non-empty string"),
            ("container.image boolean", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: app\n      image: false\n", "Container at index 0 'image' must be a non-empty string"),
            ("container.image numeric", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: app\n      image: 888\n", "Container at index 0 'image' must be a non-empty string"),
            ("container.image whitespace", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: pod\nspec:\n  containers:\n    - name: app\n      image: '  '\n", "Container at index 0 'image' must be a non-empty string"),
        ]

        for label, yaml_str, expected_err_part in cases:
            res = KubernetesPodValidator.validate_pod_content(yaml_str)
            self.assertFalse(res["valid"], f"Expected failure for {label}")
            self.assertTrue(any(expected_err_part in err for err in res["errors"]), f"Expected '{expected_err_part}' in {res['errors']} for {label}")


if __name__ == "__main__":
    unittest.main()
