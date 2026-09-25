# Interview Cheat Sheet — Reserve Bank Demo

*Quick reference for the Federal Reserve Bank of Boston LiteLLM/AI-gateway interview.*

## The one-sentence pitch

I'm standing up a single LiteLLM AI gateway in AWS that controls access to Claude through FedRAMP-authorized Bedrock, with per-key model ACLs, budgets, gateway-level guardrails, and audit logging.

## The six-step control narrative

1. **Authenticate.** Every caller presents a virtual key. No key, no conversation.
2. **ACL.** Each key is scoped to specific models and a budget.
3. **Topic guardrail.** The gateway denies off-topic or disallowed prompts before they reach a model.
4. **Route.** The gateway forwards allowed requests to Bedrock and returns the response.
5. **Redact.** The gateway strips sensitive patterns from the response before it reaches the caller.
6. **Audit.** Every request, key, model, spend, and guardrail decision is logged.

---

## Phase 0 — Baseline host security

**What it brings:** A hardened host before any service runs.

**What we did:** Fresh t3.large with Ubuntu 24.04.5, SSH key-only auth, UFW default-deny with only port 22 open, fail2ban, patched packages, and a mode-600 `.env` file.

**How it integrates:** This is the foundation. Every later layer assumes the host exposes only SSH and that secrets live in a restricted file.

**Why this way:** You harden the box before you install software. A public-facing service with password auth or extra ports is an easy target.

**Security control:** least-privilege network surface, brute-force suppression, secret-file permissions.

---

## Phase 1 — Docker + LiteLLM gateway skeleton

**What it brings:** The single control point for all model access.

**What we did:** Installed Docker, ran Postgres 16 and LiteLLM in containers, bound LiteLLM to `127.0.0.1:4000`, configured a mock model for testing, and generated master/virtual keys.

**How it integrates:** Postgres persists LiteLLM state (keys, budgets, spend logs). LiteLLM presents one OpenAI-compatible API that apps talk to.

**Why this way:** Instead of every app holding a provider API key, they hold one LiteLLM virtual key. The gateway decides who can call what.

**Security control:** localhost binding prevents direct internet access; key hierarchy separates admin from consumer credentials.

---

## Phase 2 — Bedrock Claude provider + least-privilege IAM

**What it brings:** A real, regulated path to Claude.

**What we did:** Created an IAM user with no console access and a policy allowing only `bedrock:InvokeModel` on the Claude Haiku 4.5 inference profile and the underlying cross-region foundation models. Stored the access keys in `.env`. Added the `company-claude` model alias to LiteLLM.

**How it integrates:** LiteLLM uses the IAM user's credentials to call Bedrock when a consumer requests `company-claude`.

**Why this way:** AWS Bedrock is the government-standard, FedRAMP-authorized path for Claude. Data stays inside the AWS account boundary. Direct Anthropic API is not FedRAMP-authorized.

**Security control:** least-privilege IAM — one action, specific model ARNs, no Marketplace or extra permissions after subscription.

**Gotcha:** Newer Claude models require Bedrock inference profiles, and Anthropic requires a one-time use-case form / foundation-model agreement.

---

## Phase 3 — API management: keys, ACLs, budgets, spend logs, rotation

**What it brings:** Authentication, authorization, cost control, and audit.

**What we did:** Created tiered virtual keys (`research-tier`, `restricted-tier`, `app-tier`) with different model lists and budgets. Verified ACL denial, budget exhaustion, and key rotation. Queried `LiteLLM_SpendLogs` in Postgres.

**How it integrates:** LiteLLM enforces these natively using the Postgres database. Every request is checked against the key's `models[]` and `max_budget` before routing.

**Why this way:** This is API management. You can't run a production gateway without knowing who called what, how much they spent, and being able to revoke or rotate keys.

**Security control:** per-key blast radius, cost caps, revocation, audit trail.

**Caveat:** LiteLLM's native SpendLogs have inconsistencies (alias vs. underlying model name, occasional truncation). They're useful but not sufficient as the sole compliance audit trail. That's why Phase 4 adds a structured callback audit log.

---

## Phase 4 — Gateway guardrails callback

**What it brings:** Policy enforcement at the control point.

**What we do:** Write a LiteLLM `CustomGuardrail` in `guardrails/callback.py` with pre-call topic denial and post-call PII redaction. Emit `[bank-guardrail] ALLOW/DENIED` audit lines with the key alias.

**How it integrates:** The callback is mounted into the LiteLLM container and declared in `litellm/config.yaml` under `callbacks: guardrails.callback.BankGuardrail`. It runs on every request for every consumer.

**Why this way:** A UI-level filter can be bypassed by any client that talks directly to the gateway API. A LiteLLM callback cannot be bypassed because it runs inside the gateway on every request.

**Security control:** deterministic policy enforcement, structured audit logging, PII redaction.

---

## Phase 5 — Lock-down + production shape

**What it brings:** Network isolation and managed secrets.

**What we do:** Move from `127.0.0.1:4000` to an ALB with TLS termination. Tighten security groups (HTTPS in, SSH from a bastion only). Replace `.env` secrets with AWS Secrets Manager. Use an IAM instance role instead of static access keys.

**How it integrates:** The ALB is the only public-facing resource. It forwards traffic to the private EC2 instance's localhost LiteLLM port. Secrets Manager injects credentials at runtime or the instance role provides them via the metadata service.

**Why this way:** Nothing except the load balancer should listen on the public internet. Static keys on disk are a rotation and leak risk; instance roles eliminate them.

**Security control:** defense in depth — TLS at the edge, private subnets, least-privilege security groups, no long-lived credentials.

---

## Phase 6 — Infrastructure as Code (Terraform)

**What it brings:** Repeatable, declarative, auditable infrastructure.

**What we do:** Write a Terraform skeleton that creates VPC, subnets, security groups, IAM instance role with Bedrock invoke policy, ALB with HTTPS, and the EC2 instance.

**How it integrates:** The same architecture we've built by hand is now expressed as code. `terraform plan` shows changes; `terraform apply` creates them.

**Why this way:** Manual console work is not reproducible or auditable. IaC is how you prove what infrastructure exists, how it's configured, and how it can be rebuilt.

**Security control:** infrastructure changes are reviewed, version-controlled, and reversible.

---

## Phase 7 — Finalize and rehearse

**What it brings:** An interview-ready artifact and narrative.

**What we do:** Polish `docs/gateway-security-architecture.md`, rehearse the six-step control narrative, and prepare concise answers for common questions (Why Bedrock? Why GovCloud? Why LiteLLM? How do you rotate keys? What happens if a key leaks?).

**Why this way:** The interviewer cares more about your security reasoning than the exact CLI commands. You need to tell the story cold.

---

## FedRAMP High

**What it is:** The Federal Risk and Authorization Management Program. It standardizes security assessment and authorization for cloud services used by U.S. federal agencies. FedRAMP has three impact levels: Low, Moderate, and High. High is for systems where a security breach could cause severe impact.

**Why you use it:** It is mandatory for federal agencies and their contractors when federal data is processed, stored, or transmitted in the cloud. A bank like the Federal Reserve Bank of Boston must use FedRAMP-authorized services.

**Where it is in AWS:** FedRAMP High authorization applies to the **AWS GovCloud (US)** regions. You cannot achieve FedRAMP High in the standard commercial regions.

**What's included:** FedRAMP High covers the full NIST 800-53 High control baseline — access control, audit logging, encryption, incident response, continuous monitoring, and more. AWS holds a Provisional Authority to Operate (P-ATO), which agencies can leverage for their own authorizations.

---

## AWS GovCloud (US)

**What it is:** Isolated AWS regions designed for U.S. government, defense, and regulated workloads. They are physically and logically separate from AWS commercial regions.

**Why you use it:** Data residency, compliance separation, and access to FedRAMP High / DoD SRG IL-4/IL5 authorized services. Only vetted U.S. persons can hold accounts, and support is U.S.-based.

**Where it is:** Two regions:
- AWS GovCloud (US-West) — `us-gov-west-1`
- AWS GovCloud (US-East) — `us-gov-east-1`

**What's included:** A subset of AWS services that meet government compliance requirements. Critically for this demo, **Amazon Bedrock in GovCloud is FedRAMP High and DoD IL-4/IL5 approved** for specific models, including Anthropic Claude and Meta Llama, as of June 2025.

**Key implication:** For the Federal Reserve, the answer to "how do we run Claude?" is "Amazon Bedrock in AWS GovCloud (US) with FedRAMP High controls." Not direct Anthropic API. Not commercial-region Bedrock.

---

## Common interview talking points

- **Why LiteLLM?** It gives one OpenAI-compatible API front door to many providers, with native virtual keys, model ACLs, budgets, and callback hooks.
- **Why Bedrock?** FedRAMP-authorized, data stays in AWS, no direct third-party contract needed.
- **Why GovCloud?** Required for FedRAMP High; isolated from commercial cloud.
- **Why gateway-level guardrails?** UI filters are bypassable. Gateway callbacks are not.
- **What if a key leaks?** Revoke it immediately with `/key/delete`, issue a replacement, and review `LiteLLM_SpendLogs` for unauthorized usage.
- **How do you rotate provider credentials?** Move from static IAM user keys (Phase 2 teaching step) to an IAM instance role (Phase 5/6) so there are no credentials on disk to rotate.
