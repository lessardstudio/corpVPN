# Repository Productization Plan

This plan ensures the repository is ready for GitHub, CI/CD, and robust Docker deployment.

## 1. Git Configuration
-   **Update `.gitignore`**: Ensure it excludes `.env`, `venv/`, `__pycache__`, `*.log`, `blitz_data/`, `automation_data/`, and system files.
-   **Secrets Cleanup**: Scan for any hardcoded secrets in scripts (e.g., in `setup_env.sh` or `install_manual_blitz.sh`) and replace them with placeholders or environment variable references.

## 2. Docker Standardization
-   **Standardize `docker-compose.yml`**: 
    -   Restore the **Full Docker Stack** (Blitz + Mongo + Automation) as the default `docker-compose.yml`. This is the best experience for new users.
    -   Ensure `automation-service` in the full stack uses the internal Docker network (`blitz:8000`) instead of host networking.
    -   Rename the current hybrid config to `docker-compose.hybrid.yml` for reference.
-   **Verify Dockerfiles**: Ensure all Dockerfiles use pinned base images and optimized layers.

## 3. CI/CD Pipeline
-   **Create `.github/workflows/ci.yml`**:
    -   Trigger on push/pull_request to `main`.
    -   Job 1: Linting (Python).
    -   Job 2: Docker Build Test (build images to ensure Dockerfiles are valid).

## 4. Documentation
-   **Rewrite `README.md`**:
    -   **Introduction**: What this project does.
    -   **Quick Start (Docker)**: `git clone` -> `.env` -> `docker-compose up`.
    -   **Manual Deployment**: Reference `scripts/install_manual_blitz.sh`.
    -   **Architecture**: Brief explanation of services.
