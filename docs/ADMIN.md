# Administration

Roles are `SUPER_ADMIN`, `FINANCE`, `RISK`, `OPERATIONS`, `AUDITOR`, and `READ_ONLY`. Grant records live in `admin_roles`; every prepared action is written to `admin_audit_logs` and `safe_proposals` before a Safe transaction is proposed.

Open `/admin` for the dedicated administration entry. The interface is informational until a wallet completes SIWE and the API confirms its role. No button is permitted to bypass a Safe or send funds directly.
