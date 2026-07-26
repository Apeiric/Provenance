# Provenance (demo name: ProofPay)

ProofPay is a pre-payment evidence firewall for autonomous AI agents. A
primary agent may propose a purchase, but it cannot execute payment. A guardian
verifies the proposal's evidence and policy constraints, records the decision
provenance, and is the only component allowed to call the payment adapter.

## Non-negotiable architecture

1. The primary agent emits a typed `PaymentProposal`.
2. Deterministic code verifies URLs, amounts, policy limits, and evidence.
3. The guardian returns approve, reject, or escalate with explicit reasons.
4. Every proposal and verdict is stored in the Jac graph.
5. Only an approved verdict can reach the payment adapter.

The guardian must not be another LLM casually judging the first LLM. LLMs may
extract or summarize evidence; deterministic checks decide whether money moves.

## Local development

Jac on Windows must run in WSL. Keep this repository on WSL's native Linux
filesystem, not under OneDrive or `/mnt/c`.

```bash
wsl
cd ~/projects/Provenance
jac --version
jac install
jac check .
jac test
jac start --dev main.jac
```

Open the correct copy in VS Code from the same WSL terminal:

```bash
code ~/projects/Provenance
```

The app is then available at the local URL printed by `jac start`. Run the
bounded startup check with:

```bash
bash scripts/verify-runtime.sh
```

Never commit API keys or payment credentials. Add secrets to the shell
environment or the deployment secret store.

## Hackathon gates

- Keep at least 40% of the implementation in meaningful Jac.
- Submit the partial Devpost entry by 5:50 PM.
- Treat 7:15 PM as the hard final deadline.
- Build one reliable four-minute demo path before adding optional features.

Reference: [Jac documentation](https://docs.jaseci.org/),
[Jac source](https://github.com/jaseci-labs/jac), and
[JacHacks SF guide](https://jachacks.org/sf-guide/).
