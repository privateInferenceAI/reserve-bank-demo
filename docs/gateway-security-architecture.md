# Gateway Security Architecture

*Living document for the reserve-bank-demo. Updated per phase.*

## What this is

I'm standing up a single LiteLLM AI gateway that controls access to Claude through AWS Bedrock. The design is intentionally small and security-first: one public entry point, no secrets in source, every call authenticated, authorized, logged, and redacted.

## Control narrative (six steps)

1. **Authenticate.** Every caller presents a virtual key. No key, no conversation.
2. **ACL.** Each key is scoped to specific models and a budget. A research key cannot call the expensive model, and a restricted key cannot spend past its cap.
3. **Topic guardrail.** Before the request leaves the gateway, a callback checks content against policy and denies off-topic or disallowed prompts.
4. **Route.** The gateway forwards the allowed request to Bedrock (or an optional local model tier) and returns the response.
5. **Redact.** The gateway strips sensitive patterns from the response before it reaches the caller.
6. **Audit.** Every request, key alias, model, spend, and guardrail decision lands in the database and in logs.

## Phase 0 — Baseline host security

*Status: in progress.*

- Fresh t3.large, Ubuntu 24.04, 40–60 GB disk.
- SSH key only; password auth disabled.
- UFW default deny incoming, allow SSH only.
- fail2ban for brute-force suppression.
- System packages updated and upgraded.
- `.env` file created with mode 600; Secrets Manager later.

## Upcoming phases

- Phase 1: Docker + LiteLLM skeleton + Postgres + first virtual key.
- Phase 2: Bedrock Claude provider + least-privilege IAM.
- Phase 3: Virtual-key tiers, budgets, spend logs, rotation.
- Phase 4: Gateway guardrails callback (topic denial + PII redaction).
- Phase 5: Lock-down binding, ALB + TLS, security groups, Secrets Manager.
- Phase 6: Terraform IaC skeleton.
- Phase 7: Finalize narrative and rehearse.

## What I recommend for a bank environment

- Run the gateway in a private subnet. Put an ALB in front for TLS termination. Nothing else listens on the host.
- Use IAM instance roles or IRSA, never long-lived keys.
- Keep model access behind Bedrock for FedRAMP-authorized inference.
- Log everything to a durable store with retention and tamper protection.
- Rotate virtual keys on a schedule and on departure.
- Treat guardrails as enforceable policy at the gateway, not advice in the UI.
