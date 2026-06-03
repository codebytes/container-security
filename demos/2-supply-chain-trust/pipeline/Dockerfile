# syntax=docker/dockerfile:1.6

# Base images are pinned by digest for reproducible, tamper-evident builds.
# Digests resolved 2026-05-30 via `docker buildx imagetools inspect <ref>` and
# shared with demo 3 (verified multi-arch INDEX digests: linux/amd64 + arm64).
# To refresh: re-resolve the digest for the desired tag and replace below.
#   python:3.11-slim                     -> sha256:a3ab0b96...e49ac0
#   gcr.io/distroless/python3-debian12   -> sha256:2fdb0540...73731f
#
# Why distroless for the final stage: the previous `python:3.11-slim` runtime
# carried 9 HIGH/CRITICAL CVEs (perl-base, ncurses, wheel, ...), which hard-
# blocked the Trivy gate before the sign/verify/admission story could run.
# Distroless ships no shell/package manager and a tiny surface, so the
# "scan -> sign -> verify -> admit" narrative stays honest (gate passes).
FROM python:3.11-slim@sha256:a3ab0b966bc4e91546a033e22093cb840908979487a9fc0e6e38295747e49ac0 AS build
WORKDIR /app
ENV PIP_NO_CACHE_DIR=1
COPY app/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip "setuptools>=78.1.1" \
 && pip install --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3-debian12@sha256:2fdb05402a2cf21cf78fdb3ba4c5db167241e9e498140f5bf689d7efb773731f
WORKDIR /app
# distroless python3-debian12 ships Python 3.11.2 whose sys.path is
# /usr/lib/python3.11 (+ lib-dynload) — it does NOT include the build stage's
# /usr/local/lib/python3.11/site-packages. Copying there left deps unimportable
# (`ModuleNotFoundError: flask`) and made syft see 0 packages. Copy into a path
# on the distroless interpreter's search path and pin PYTHONPATH so the deps are
# importable at runtime AND visible to the SBOM scan.
ENV PYTHONPATH=/usr/lib/python3.11/site-packages
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/lib/python3.11/site-packages
COPY app/ /app/
# distroless ships a built-in non-root user at numeric UID 65532. Using the
# numeric UID (not a name) lets Kubernetes `runAsNonRoot: true` verify the user
# at admission without needing an /etc/passwd entry. Pair this image with
# `runAsNonRoot: true` + `runAsUser: 65532` in the pod securityContext.
USER 65532
ENV PYTHONUNBUFFERED=1
EXPOSE 8080
ENTRYPOINT ["python", "/app/main.py"]
