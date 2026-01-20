I will implement a robust logging system to ensure all events are recorded for future improvements.

### 1. Create `automation-service/logger.py`
- Create a new module to centralize logging configuration.
- Implement `setup_logging()` to configure:
  - **Console Output**: For Docker logs (via `docker logs`).
  - **File Output**: Rotating log files (max 10MB, 5 backups) stored in `logs/app.log`.
  - **Format**: `%(asctime)s - %(name)s - %(levelname)s - %(message)s`.

### 2. Update `automation-service/main.py`
- Import and call `setup_logging()` at application startup.
- This will automatically capture logs from all modules (`monitor.py`, `telegram_2fa.py`, `webhooks.py`, etc.) that use `logging.getLogger(__name__)`.

### 3. Update `docker-compose.yml`
- Add a volume mapping `./automation_logs:/app/logs` to the `automation-service`.
- This ensures logs are persisted on the host machine in the `automation_logs` folder, even if the container is recreated.

### Verification
- I will rebuild the container and verify that `automation_logs/app.log` is created and populated with startup logs.