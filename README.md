# Guardians of the Container Galaxy: Defending the Cosmic Cluster

This repository contains a pragmatic container security framework mapped onto a memorable "Guardians of the Galaxy" crew metaphor. Each character archetype represents a critical defensive layer—supply chain integrity, runtime behavioral detection, zero‑trust networking, and observability—to help teams remember and implement comprehensive container security practices.

## Slides

Slides can be found at [chris-ayers.com/container-security](https://chris-ayers.com/container-security)

## Demos

Hands-on walkthroughs live under `demos/` for each Guardian archetype:

1. [demos/1-policy-guardrails/](demos/1-policy-guardrails/) – **Star-Lord**: Kyverno + Cosign admission enforcement
2. [demos/2-supply-chain-trust/](demos/2-supply-chain-trust/) – **Gamora**: SBOM, scanning, signing pipeline
3. [demos/3-image-hardening/](demos/3-image-hardening/) – **Rocket**: Dockerfile before/after with Trivy diff
4. [demos/4-runtime-detection/](demos/4-runtime-detection/) – **Drax**: Falco custom rule + controlled trigger
5. [demos/5-zero-trust-networking/](demos/5-zero-trust-networking/) – **Groot**: Deny-by-default NetworkPolicies
6. [demos/6-observability-signals/](demos/6-observability-signals/) – **Mantis**: OTEL telemetry + Falco alert correlation

## Resources

- [Falco](https://falco.org)
- [Trivy](https://aquasecurity.github.io/trivy/)
- [Cosign](https://github.com/sigstore/cosign)
- [Syft](https://github.com/anchore/syft)
- [Grype](https://github.com/anchore/grype)
- [Calico](https://www.tigera.io/project-calico/)
- [Cilium](https://cilium.io)
- [Kyverno](https://kyverno.io)
- [OPA](https://www.openpolicyagent.org)
- [CNCF Cloud Native Security Whitepaper](https://www.cncf.io/projects/security/)

## Connect with Chris Ayers

Feel free to connect with Chris Ayers on social media and visit his blog for more insights on DevOps, Azure, and container security.

- Twitter: [@Chris_L_Ayers](https://twitter.com/Chris_L_Ayers)
- Mastodon: [@Chrisayers@hachyderm.io](https://hachyderm.io/@Chrisayers)
- LinkedIn: [chris-l-ayers](https://linkedin.com/in/chris-l-ayers/)
- Blog: [chris-ayers.com](https://chris-ayers.com/)
- GitHub: [Codebytes](https://github.com/codebytes)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

> "We are Groot." – In security terms: we are stronger as interlocked layers, not isolated tools.