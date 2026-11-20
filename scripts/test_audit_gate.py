import copy
import unittest

from check_container_audit import evaluate


class AuditPolicyTests(unittest.TestCase):
    def setUp(self):
        self.finding = dict(
            VulnerabilityID="CVE-example",
            PkgName="libexample",
            InstalledVersion="1",
            Severity="HIGH",
        )
        self.result = {
            "Class": "os-pkgs",
            "Type": "debian",
            "Vulnerabilities": [self.finding],
        }
        self.report = {
            "Metadata": {"OS": {"Family": "debian"}},
            "Results": [self.result],
        }
        entry = dict(
            self.finding,
            Class="os-pkgs",
            Type="debian",
            kind="unfixed",
            reason="Vendor has no fix",
        )
        self.baseline = dict(
            owner="maintainer",
            tracking_issue="issue",
            findings=[entry],
        )

    def test_known_unfixed_is_reported(self):
        blocked, accepted = evaluate(self.report, self.baseline)
        self.assertFalse(blocked)
        self.assertEqual(len(accepted), 1)

    def test_new_vulnerability_blocks(self):
        self.finding["VulnerabilityID"] = "CVE-new"
        self.assertTrue(evaluate(self.report, self.baseline)[0])

    def test_fix_available_blocks(self):
        self.finding["FixedVersion"] = "2"
        self.assertTrue(evaluate(self.report, self.baseline)[0])

    def test_version_or_severity_change_requires_review(self):
        for field, value in [("InstalledVersion", "2"), ("Severity", "CRITICAL")]:
            report = copy.deepcopy(self.report)
            report["Results"][0]["Vulnerabilities"][0][field] = value
            self.assertTrue(evaluate(report, self.baseline)[0])

    def test_clean_report_passes(self):
        self.result["Vulnerabilities"] = []
        self.assertEqual(evaluate(self.report, self.baseline), ([], []))

    def test_unused_baseline_entries_do_not_block_a_clean_report(self):
        self.result.pop("Vulnerabilities")
        self.assertEqual(evaluate(self.report, self.baseline), ([], []))

    def test_baseline_without_review_due_is_accepted(self):
        self.assertNotIn("review_due", self.baseline)
        self.assertEqual(len(evaluate(self.report, self.baseline)[1]), 1)

    def test_missing_scan_results_fails_closed(self):
        with self.assertRaises(ValueError):
            evaluate({}, self.baseline)

    def test_pip_exception_does_not_cover_other_packages(self):
        self.baseline["findings"][0]["kind"] = "pip-sbom-only"
        self.assertTrue(evaluate(self.report, self.baseline)[0])


if __name__ == "__main__":
    unittest.main()
