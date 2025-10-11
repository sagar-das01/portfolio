# Google Cloud VM Deployment Guide

This guide explains how to set up automatic deployment of your React portfolio to a Google Cloud VM using GitHub Actions.

## 🏗️ System Overview

The deployment system includes:
- **Automated GitHub workflows** that trigger on new releases
- **VM deployment scripts** for installing, updating, and restarting the application
- **Backup and rollback mechanisms** for safe deployments
- **Health checks and monitoring** to ensure successful deployments

## 📋 Prerequisites

1. **Google Cloud Account** with billing enabled
2. **Google Cloud VM** (Ubuntu 20.04+ recommended)
3. **GitHub repository** with admin access
4. **Domain name** (optional, for custom domain setup)

## 🚀 Initial Setup

### Step 1: Create Google Cloud VM

1. **Create a new VM instance:**
   ```bash
   gcloud compute instances create portfolio-vm \
     --zone=us-central1-a \
     --machine-type=e2-medium \
     --subnet=default \
     --network-tier=PREMIUM \
     --maintenance-policy=MIGRATE \
     --scopes=https://www.googleapis.com/auth/cloud-platform \
     --tags=http-server,https-server \
     --image=ubuntu-2004-focal-v20231213 \
     --image-project=ubuntu-os-cloud \
     --boot-disk-size=20GB \
     --boot-disk-type=pd-standard
   ```

2. **Configure firewall rules:**
   ```bash
   gcloud compute firewall-rules create allow-http-portfolio \
     --allow tcp:80 \
     --source-ranges 0.0.0.0/0 \
     --target-tags http-server
   
   gcloud compute firewall-rules create allow-https-portfolio \
     --allow tcp:443 \
     --source-ranges 0.0.0.0/0 \
     --target-tags https-server
   ```

3. **Get VM external IP:**
   ```bash
   gcloud compute instances describe portfolio-vm \
     --zone=us-central1-a \
     --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
   ```

### Step 2: Setup VM Environment

1. **SSH into your VM:**
   ```bash
   gcloud compute ssh portfolio-vm --zone=us-central1-a
   ```

2. **Run the setup script:**
   ```bash
   # Download and run the setup script
   curl -L https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/master/scripts/setup-vm.sh -o setup-vm.sh
   chmod +x setup-vm.sh
   sudo ./setup-vm.sh
   ```

   Or manually copy the script from your repository and run it.

### Step 3: Configure GitHub Secrets
**⚠️ CRITICAL SECURITY NOTE: NEVER store these secrets in your repository files, commit them to Git, or share them publicly. These secrets contain sensitive credentials that could compromise your Google Cloud account.**

Add these secrets in your GitHub repository's **encrypted secrets storage** (`Settings > Secrets and variables > Actions > New repository secret`):

| Secret Name | Description | Example Value | ⚠️ Security Level |
|-------------|-------------|---------------|-------------------|
| `GCP_PROJECT_ID` | Your Google Cloud Project ID | `my-portfolio-project` | 🟡 Sensitive |
| `GCP_SA_KEY` | Service Account JSON key | `{"type": "service_account"...}` | 🔴 **HIGHLY SENSITIVE** |
| `GCP_VM_IP` | Your VM's external IP address | `34.123.45.67` | 🟡 Sensitive |
| `GCP_VM_USER` | Username for SSH access | `your-username` | 🟡 Sensitive |
| `GCP_SSH_PRIVATE_KEY` | Private SSH key for VM access | `-----BEGIN OPENSSH PRIVATE KEY-----...` | 🔴 **HIGHLY SENSITIVE** |

#### 🔒 How to Safely Add Secrets to GitHub:

1. **Go to your GitHub repository**
2. **Click Settings** (in the repository, not your account)
3. **Navigate to:** `Secrets and variables > Actions`
4. **Click "New repository secret"**
5. **Add each secret individually** with the exact name from the table above
6. **Paste the secret value** (GitHub will encrypt it automatically)
7. **Click "Add secret"**

#### 🚫 What NOT to do:
- ❌ Never put secrets in `.env` files that are committed to Git
- ❌ Never put secrets directly in workflow files
- ❌ Never put secrets in README files or documentation
- ❌ Never share secrets in chat, email, or other communication
- ❌ Never store secrets in public repositories or gists

#### Creating Service Account Key:

**🔒 SECURITY REMINDER: The service account key is extremely sensitive. Treat it like a password that gives full access to your Google Cloud resources.**

1. **Create service account:**
   ```bash
   gcloud iam service-accounts create portfolio-deployer \
     --description="Service account for portfolio deployment" \
     --display-name="Portfolio Deployer"
   ```

2. **Grant necessary permissions:**
   ```bash
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:portfolio-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/compute.instanceAdmin"
   ```

#### Setting up SSH Keys:
   ```bash
   gcloud iam service-accounts keys create portfolio-key.json \
     --iam-account=portfolio-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com
   ```

   **⚠️ IMPORTANT:** 
   - Copy the contents of `portfolio-key.json` to your GitHub secret `GCP_SA_KEY`
   - **Immediately delete** `portfolio-key.json` from your local machine after copying
   - **Never commit** this file to Git or share it

2. **Click Settings** (in the repository, not your account)

**🔒 SECURITY REMINDER: SSH private keys provide direct access to your VM. Keep them secure.**

   ```bash
   ssh-keygen -t rsa -b 4096 -C "github-actions@your-domain.com" -f ~/.ssh/portfolio-deploy
   ```
- ❌ Never put secrets in `.env` files that are committed to Git

   ```bash
   gcloud compute instances add-metadata portfolio-vm \
     --zone=us-central1-a \
     --metadata-from-file ssh-keys=~/.ssh/portfolio-deploy.pub
   ```

3. **Add private key to GitHub secrets** (copy content of `~/.ssh/portfolio-deploy`)
3. **Add private key to GitHub secrets:**
   - Copy the contents of `~/.ssh/portfolio-deploy` (the private key, no `.pub` extension)
   - Add it to GitHub secret `GCP_SSH_PRIVATE_KEY`
   - **Securely delete** the private key from your local machine after copying
   - Keep only the public key if needed for future VM access

#### 🔐 Additional Security Measures:

1. **Rotate secrets regularly** (every 3-6 months)
2. **Use least-privilege principle** - only grant minimum necessary permissions
3. **Monitor access logs** in Google Cloud Console
4. **Enable 2FA** on your Google Cloud and GitHub accounts
5. **Set up alerting** for unusual deployment activity

## 🔄 How Deployments Work
### Automatic Deployment Trigger

Deployments are triggered automatically when:
1. **New release is published** - The `deploy-gcp.yml` workflow runs automatically
2. **Manual trigger** - You can manually trigger deployment from GitHub Actions

### Deployment Process

1. **Pre-deployment checks:**
   - Verify VM connectivity
   - Check current version
   - Create backup of existing deployment

2. **Deployment steps:**
   - Transfer deployment scripts to VM
   - Download new release artifacts
   - Stop services gracefully
   - Update application files
   - Restart services
   - Perform health checks

3. **Post-deployment:**
   - Verify application is running
   - Clean up temporary files
   - Send deployment notifications

### Rollback on Failure

If deployment fails:
- Automatic rollback to previous version
- Services are restored from backup
- Error notifications are sent

## 📜 Available Scripts

### `/scripts/deploy.sh`
**Purpose:** Complete deployment of a new version
```bash
sudo ./deploy.sh v1.2.3
```

**Features:**
- Downloads release artifacts
- Creates backups
- Updates application
- Configures web server
- Performs health checks
- Automatic rollback on failure

### `/scripts/update.sh`
**Purpose:** Update from one version to another
```bash
sudo ./update.sh v1.2.3
```

**Features:**
- Version comparison and validation
- Configuration migrations
- Graceful service updates
- Backup management

### `/scripts/restart.sh`
**Purpose:** Restart application services
```bash
sudo ./restart.sh [--graceful|--force|--status]
```

**Options:**
- `--graceful` (default): Graceful restart with health checks
- `--force`: Force restart of all services
- `--status`: Show current service status

### `/scripts/setup-vm.sh`
**Purpose:** Initial VM setup and configuration
```bash
sudo ./setup-vm.sh
```

**What it does:**
- Installs Node.js, Yarn, PM2, Nginx
- Configures firewall and security
- Sets up directory structure
- Creates monitoring services

## 🔧 Manual Operations

### Check Deployment Status
```bash
# Check service status
sudo systemctl status nginx
sudo /opt/portfolio-scripts/restart.sh --status

# Check application logs
sudo tail -f /var/log/portfolio-deploy.log
sudo journalctl -u nginx -f

# Check current version
grep '"version"' /var/www/portfolio/package.json
```

### Manual Deployment
```bash
# Deploy specific version
sudo /opt/portfolio-scripts/deploy.sh v1.2.3

# Update to latest
sudo /opt/portfolio-scripts/update.sh $(curl -s https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
```

### Backup Management
```bash
# List backups
sudo ls -la /var/backups/portfolio/

# Restore from backup
sudo systemctl stop nginx
sudo rm -rf /var/www/portfolio/*
sudo cp -r /var/backups/portfolio/BACKUP_NAME/* /var/www/portfolio/
sudo chown -R www-data:www-data /var/www/portfolio
sudo systemctl start nginx
```

## 🔍 Monitoring and Logs

### Important Log Files
- `/var/log/portfolio-deploy.log` - Deployment logs
- `/var/log/portfolio-update.log` - Update logs  
- `/var/log/portfolio-restart.log` - Restart logs
- `/var/log/nginx/access.log` - Web server access logs
- `/var/log/nginx/error.log` - Web server error logs

### Health Check Endpoints
- `http://YOUR_VM_IP/` - Main application
- `http://YOUR_VM_IP/health` - Health check endpoint

### Monitoring Commands
```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep nginx

# Check network connections
netstat -tlnp | grep :80
```

## 🛡️ Security Considerations

1. **Firewall Configuration:**
   - Only ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) are open
   - SSH access is key-based only

2. **Service Permissions:**
   - Application runs as `www-data` user
   - Scripts run with minimal required permissions

3. **Backup Security:**
   - Backups are stored locally with root permissions
   - Automatic cleanup of old backups

4. **Network Security:**
   - Security headers configured in Nginx
   - HTTPS ready (SSL certificate setup required)

## 🚨 Troubleshooting

### Common Issues

**❌ Deployment fails with SSH connection error:**
```bash
# Check VM status
gcloud compute instances list
# Verify SSH key is correctly added to VM metadata
```

**❌ Application not accessible after deployment:**
```bash
# Check nginx status
sudo systemctl status nginx
# Check application files
ls -la /var/www/portfolio/
# Check firewall
sudo ufw status
```

**❌ GitHub Actions workflow fails:**
- Verify all secrets are correctly set
- Check workflow logs for specific error messages
- Ensure VM is running and accessible

### Recovery Procedures

**🔄 Emergency rollback:**
```bash
sudo /opt/portfolio-scripts/restart.sh --force
# If that doesn't work, restore from backup manually
```

**🔄 Complete re-deployment:**
```bash
# Re-run setup script
sudo /path/to/setup-vm.sh
# Deploy latest version
sudo /opt/portfolio-scripts/deploy.sh latest
```

## 📊 Workflow Integration

The deployment system integrates with your existing versioning workflow:

1. **Create feature branch** with version pattern (e.g., `feature/minor/new-feature`)
2. **Merge PR to master** → Triggers automated versioning
3. **New release is created** → Triggers automatic deployment to VM
4. **Application is live** on your Google Cloud VM

## 🎯 Best Practices

1. **Always test in staging** before deploying to production
2. **Monitor deployment logs** during and after deployment
3. **Keep backups** - the system maintains automatic backups
4. **Use health checks** before announcing new releases
5. **Plan for rollbacks** - understand the rollback process
6. **Monitor resource usage** on your VM

## 📈 Scaling Considerations

For high-traffic applications, consider:
- **Load balancers** for multiple VM instances
- **Database separation** if you add backend functionality
- **CDN integration** for static asset delivery
- **Container orchestration** with Kubernetes
- **Monitoring solutions** like Google Cloud Monitoring

---

Your portfolio is now ready for automated deployment to Google Cloud! 🚀

For questions or issues, check the troubleshooting section or create an issue in your repository.
