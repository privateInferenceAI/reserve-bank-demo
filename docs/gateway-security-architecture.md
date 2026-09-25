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

*Status: complete (2026-09-24).*

Build target: t3.large, Ubuntu 24.04.5 LTS, 50 GB gp3 root volume, IMDSv2 enforced.

What I configured:

- SSH key-only auth, root login disabled, password auth disabled. The drop-in config lives in /etc/ssh/sshd_config.d/99-hardening.conf.
- UFW default deny incoming, allow outgoing, with only port 22/tcp open.
- fail2ban jail for sshd: 5 failed attempts in 10 minutes triggers a 1-hour ban.
- System packages updated and upgraded; ufw, fail2ban, curl, jq installed.
- Project cloned to /opt/reserve-bank-demo with a .env skeleton at mode 600.

Verification at the end of Phase 0:

- Listening ports: only 22 (sshd). Local DNS stub on 127.0.0.53:53 is loopback-only and expected.
- SSH hardening: permitrootlogin no, passwordauthentication no, pubkeyauthentication yes.
- UFW active, rule set reduced to 22/tcp.
- fail2ban sshd jail active, zero bans at baseline.
- .env permissions confirmed 600.

Open item for Phase 2: AWS Bedrock serverless model access is auto-enabled on first invocation, but Anthropic may ask for first-time use-case details.

## Phase 1 — Docker + LiteLLM gateway skeleton

*Status: complete (2026-09-24).*

What I configured:

- Docker Engine and Docker Compose plugin installed from the official repository.
- Postgres 16 (Alpine) container for LiteLLM state: virtual keys, budgets, spend logs, request metadata.
- LiteLLM container bound to 127.0.0.1:4000 only, with a mock model alias for end-to-end testing.
- Secrets generated with openssl rand and stored in /opt/reserve-bank-demo/.env at mode 600.
- Master key / virtual key hierarchy established. The master key administers keys; the virtual key is what a consumer holds.

Verification at the end of Phase 1:

- docker compose ps shows gw-postgres and gw-litellm both healthy.
- curl http://127.0.0.1:4000/health/liveliness returns "I'm alive!".
- POST /key/generate with the master key minted a virtual key scoped to model alias gateway-test.
- POST /v1/chat/completions with the virtual key returned the mock response.

Why Postgres matters: LiteLLM persists keys, budgets, and spend in the database. Without it, every container restart would lose your key state and you couldn't audit usage.

## Phase 2 — Bedrock Claude provider + least-privilege IAM

*Status: complete (2026-09-24).*

What I configured:

- IAM user `reserve-bank-litellm` with no console access.
- IAM policy `reserve-bank-bedrock-haiku` allowing only `bedrock:InvokeModel` on:
  - the inference profile `arn:aws:bedrock:us-east-1:426063972668:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0`
  - the underlying foundation model ARNs in us-east-1, us-east-2, and us-west-2 (cross-region inference routing).
- AWS access keys for that user stored in `.env` at mode 600.
- LiteLLM config updated with `company-claude` alias pointing to `bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0`.
- Bedrock model access enabled for the account (admin-level one-time agreement + use-case form).

Verification at the end of Phase 2:

- POST /v1/chat/completions with the `phase2-claude` virtual key returns a real Claude response through Bedrock.
- IAM policy has no Marketplace or extra permissions after the one-time subscription was completed.

Why Bedrock for a bank: AWS Bedrock is the government-standard path for Claude because it is FedRAMP-authorized and data stays within the AWS account boundary. Direct Anthropic API is a one-line config swap, but it is not the regulated path.

Open item for Phase 5/6: replace the static AWS access keys with an IAM instance role attached to the EC2 instance.

## Upcoming phases

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
