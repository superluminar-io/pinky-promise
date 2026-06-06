---
name: api-check-external
description: "ALWAYS invoke this alongside superpowers:brainstorming. Checks whether any external APIs or services mentioned in the conversation (GitHub, Stripe, Twilio, any third-party API) have registry entries. Required for clients and tools as well as services. If no external service is mentioned, exit immediately."
---

# API External Dependency Check

Surface missing registry entries for external services mentioned in the conversation.

## What to do

For each external service named in the user's message that is not developed in this repo:

Surface immediately:
> "The design depends on `<service>` but no public API entry exists in the registry. Run `/api-spec-import <url>` to register it before planning begins."

If `API_REGISTRY_REPO` is not configured, skip this check silently.

Do not block the conversation — surface the suggestion and continue.
