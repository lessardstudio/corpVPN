# VPS Configuration Plan

I will update the deployment scripts to strictly follow the provided 7-step VPS setup guide.

## 1. Update `scripts/prepare_vps.sh`
- **Goal**: Comply with Step 3.
- **Action**: Add `nano` and `htop` to the installation list.
- **Result**: `apt install -y nano htop wget curl git ufw` (and others needed for the project).

## 2. Create `scripts/setup_user_ssh.sh`
- **Goal**: Comply with Steps 5 and 6.
- **Action**: Create a new script that:
  - Creates a new sudo user (interactive input).
  - Backs up `/etc/ssh/sshd_config`.
  - Changes SSH port (interactive input, default 2222).
  - Disables root login (`PermitRootLogin no`).
  - Restarts SSH service.

## 3. Update `scripts/configure_security.sh`
- **Goal**: Comply with Step 4 and ensure firewall matches SSH config.
- **Action**:
  - Accept the custom SSH port as a variable.
  - Allow the new SSH port in UFW.
  - Allow HTTP/HTTPS (Step 4).
  - Remove/Deny port 22 if changed.

## 4. Update `scripts/deploy_vps.sh`
- **Goal**: Orchestrate the new security steps.
- **Action**:
  - Add prompts for "New Username", "New Password", and "SSH Port".
  - Pass these values to the setup scripts.

## 5. Documentation
- **Goal**: Update `DEPLOYMENT.md` to reflect the secure setup process and new default ports.

This approach ensures your VPS is hardened exactly as requested while maintaining the functionality of the VPN gateway.