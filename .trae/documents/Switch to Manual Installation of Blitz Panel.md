# Manual Installation of Blitz Panel (Non-Docker)

This plan transitions the Blitz service from Docker to a direct system installation.

## Prerequisites
1.  **Source Code Upload**: The `blitz_source` directory MUST be uploaded to `/root/corpVPN/blitz_source` on the VPS.

## Implementation Steps
1.  **Install System Dependencies**:
    - Install `mongodb-org`, `python3`, `python3-venv`, `python3-pip`.
    - Download and install the `hysteria` binary to `/usr/local/bin/`.
2.  **Setup Python Environment**:
    - Create a virtual environment: `python3 -m venv venv`.
    - Install dependencies: `pip install -r requirements.txt`.
3.  **Configuration Adjustments**:
    - Modify `database.py` to connect to `localhost:27017` instead of `mongo:27017`.
    - Modify `app.py` binding if necessary.
4.  **Systemd Service Creation**:
    - Create `/etc/systemd/system/blitz.service` to manage the application lifecycle.
    - Enable and start the service.
5.  **Update Automation Service**:
    - Reconfigure `automation-service` (which remains in Docker) to communicate with Blitz on the host IP.
