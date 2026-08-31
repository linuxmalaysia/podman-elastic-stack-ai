"""
Quadlet and Kubernetes Pod Manifest Schema Validation Module.
Validates generated Quadlet `.kube` and `.yaml` Kubernetes Pod manifests
against Podman 5+ specifications using standard library or lightweight YAML parsing.
"""

import configparser
import re
import unittest


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

        if "Unit" not in config:
            errors.append("Missing required [Unit] section")
        elif "Description" not in config["Unit"]:
            errors.append("Missing Description in [Unit] section")

        if "Kube" not in config:
            errors.append("Missing required [Kube] section")
        else:
            kube_sec = config["Kube"]
            if "Yaml" not in kube_sec:
                errors.append("Missing Yaml key in [Kube] section")

        if "Install" not in config:
            errors.append("Missing required [Install] section")
        elif "WantedBy" not in config["Install"]:
            errors.append("Missing WantedBy in [Install] section")

        return {"valid": len(errors) == 0, "errors": errors}


class KubernetesPodValidator:
    """Validates Kubernetes Pod manifest schemas (.yaml) used by Podman 5+ Quadlet Kube."""

    @classmethod
    def validate_pod_content(cls, content: str) -> dict:
        errors = []

        # Check basic structural specs using regex for dependency-free Python execution
        api_match = re.search(r"^\s*apiVersion:\s*([^\s]+)", content, re.MULTILINE)
        if not api_match or api_match.group(1).strip("'\"") != "v1":
            errors.append("apiVersion must be 'v1'")

        kind_match = re.search(r"^\s*kind:\s*([^\s]+)", content, re.MULTILINE)
        if not kind_match or kind_match.group(1).strip("'\"") != "Pod":
            errors.append("kind must be 'Pod'")

        if not re.search(r"^\s*metadata:\s*$", content, re.MULTILINE) or not re.search(r"^\s*name:\s*[^\s]+", content, re.MULTILINE):
            errors.append("metadata must contain 'name'")

        if not re.search(r"^\s*containers:\s*$", content, re.MULTILINE):
            errors.append("spec.containers must be a non-empty list")
        else:
            if not re.search(r"^\s*-\s*name:\s*[^\s]+", content, re.MULTILINE):
                errors.append("Containers must specify 'name'")
            if not re.search(r"^\s*image:\s*[^\s]+", content, re.MULTILINE):
                errors.append("Containers must specify 'image'")

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

    def test_invalid_quadlet_kube_missing_sections(self):
        invalid_kube = (
            "[Unit]\n"
            "Description=Missing Kube Section\n"
        )
        result = QuadletKubeValidator.validate_kube_content(invalid_kube)
        self.assertFalse(result["valid"])
        self.assertIn("Missing required [Kube] section", result["errors"])

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

    def test_invalid_pod_yaml(self):
        invalid_yaml = (
            "apiVersion: v2\n"
            "kind: Deployment\n"
        )
        result = KubernetesPodValidator.validate_pod_content(invalid_yaml)
        self.assertFalse(result["valid"])
        self.assertIn("apiVersion must be 'v1'", result["errors"])
        self.assertIn("kind must be 'Pod'", result["errors"])


if __name__ == "__main__":
    unittest.main()
