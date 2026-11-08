# Security policy

AutoInstallTools installs third-party security utilities. Use them only on
systems and applications you own or are explicitly authorized to assess.

## Reporting a vulnerability

Please do not open a public issue for an exploitable vulnerability. Use GitHub's
private vulnerability reporting for this repository. Include the affected
commit, reproduction steps, and impact; omit credentials, customer data, and
real assessment targets. We will acknowledge reports as soon as practical and
coordinate a fix and disclosure with the reporter.

## Supply-chain notes

Release downloads should be pinned and verified against SHA-256 values. A hash
computed from an upstream asset detects later changes to the pin but does not
independently authenticate the original publisher. Review catalog changes to
install sources and checksums carefully. Do not run the installer as root.
