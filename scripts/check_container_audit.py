"""Block new/fixable findings; retain reviewed, expiring findings in the report."""

import datetime
import json
import sys


def identity(result, finding):
    return tuple(
        [result.get("Class"), result.get("Type")]
        + [
            finding.get(k)
            for k in ("VulnerabilityID", "PkgName", "InstalledVersion", "Severity")
        ]
    )


def evaluate(report, baseline, today):
    if not isinstance(report.get("Results"), list) or not report.get(
        "Metadata", {}
    ).get("OS"):
        raise ValueError("Expected a complete Trivy container report with OS metadata")
    if not any(r.get("Class") == "os-pkgs" for r in report["Results"]):
        raise ValueError("OS vulnerability scan result is missing")
    if not baseline.get("owner") or not baseline.get("tracking_issue"):
        raise ValueError("Baseline needs an owner and tracking issue")
    if today >= datetime.date.fromisoformat(baseline["review_due"]):
        raise ValueError(
            "Reviewed findings expired: reassess before renewing the baseline"
        )
    known = {}
    for entry in baseline["findings"]:
        if not entry.get("reason") or entry["kind"] not in ("unfixed", "pip-sbom-only"):
            raise ValueError("Every baseline entry needs a supported reason")
        known[identity(entry, entry)] = entry
    blocked, accepted = [], []
    for result in report["Results"]:
        if result.get("Misconfigurations") or result.get("Secrets"):
            raise ValueError(
                "Unexpected additional scanner findings; review separately"
            )
        for finding in result.get("Vulnerabilities") or []:
            if finding.get("Severity") not in ("HIGH", "CRITICAL"):
                continue
            entry = known.get(identity(result, finding))
            label = " ".join(
                str(finding[k])
                for k in ("VulnerabilityID", "PkgName", "InstalledVersion")
            )
            if entry is None:
                blocked.append(label + ": new finding or changed package/severity")
            elif entry["kind"] == "unfixed" and finding.get("FixedVersion"):
                blocked.append(label + ": a fix is now available")
            elif entry["kind"] == "pip-sbom-only" and not (
                result.get("Class") == "lang-pkgs"
                and result.get("Type") == "python-pkg"
                and finding.get("VulnerabilityID") == "CVE-2025-47273"
                and finding.get("PkgName") == "setuptools"
                and finding.get("InstalledVersion") == "70.3.0"
                and finding.get("FixedVersion") == "78.1.1"
            ):
                blocked.append(label + ": outside reviewed pip SBOM scope")
            else:
                accepted.append(label)
    return blocked, accepted


def main():
    try:
        with open(sys.argv[1]) as stream:
            report = json.load(stream)
        with open(sys.argv[2]) as stream:
            baseline = json.load(stream)
        blocked, accepted = evaluate(
            report, baseline, datetime.datetime.now(datetime.timezone.utc).date()
        )
    except (ValueError, KeyError, TypeError, IndexError, OSError) as exc:
        print(f"Audit gate failed: {exc}", file=sys.stderr)
        return 1
    print(f"Reviewed: {len(accepted)}; blocking: {len(blocked)}")
    print(f"Owner: {baseline['owner']}; review due: {baseline['review_due']}")
    print(f"Tracking: {baseline['tracking_issue']}")
    for finding in blocked:
        print(f"BLOCK: {finding}", file=sys.stderr)
    if accepted:
        print("Outstanding findings remain; see the unfiltered audit artifact.")
    return int(bool(blocked))


if __name__ == "__main__":
    sys.exit(main())
