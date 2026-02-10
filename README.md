# cloudflare-ddns-updater

📡 A simple shell script to update your Cloudflare DNS records (A/AAAA, TXT/SPF, etc.) using your current dynamic public IPs (IPv4 & IPv6).

---

## ✨ Features

* 🔄 Automatically detects your public **IPv4** and **IPv6** addresses
* 🎯 Fetches only the IP versions referenced in `config.conf`
* 🔐 Uses **Cloudflare API Token** securely via environment variables
* ⚙️ Customizable DNS update rules via `config.conf`
* 📝 Supports `{IPV4}` and `{IPV6}` placeholders in record values
* ✅ Skips updates if the DNS record already matches the current value
* 🕒 Can be fully automated via `cron` jobs
* 🛠️ Auto-installs `jq` if missing (supports `AUTO_INSTALL_JQ=true`)
* 🧱 Works on minimal systems (no `sudo` required)

---

## 📦 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/redbean0721/cloudflare-ddns-updater.git
cd cloudflare-ddns-updater
```

---

### 2. Set environment variables

You must provide:

* `CF_API_TOKEN`: Your Cloudflare API Token (with required permissions)
* `ZONE_NAME`: Your domain name (e.g. `example.com`)

You can set them temporarily:

```bash
export CF_API_TOKEN="your_cloudflare_api_token"
export ZONE_NAME="example.com"
```

Or store them in a `.env` file. Copy and edit the example:

```
cp .env.example .env
vim .env
```

The script will automatically load `.env` when run.

---

### 3. Configure DNS records

Edit `config.conf` to define the records you want to manage:

```ini
# Update A record
Type: A
Name: www
Content_Rule: "{IPV4}"

# Update AAAA record
Type: AAAA
Name: www
Content_Rule: "{IPV6}"

# Update SPF TXT record
Type: TXT
Name: @
Content_Rule: "v=spf1 ip4:{IPV4} ip6:{IPV6} mx ~all"
```

📌 Separate each record block with a blank line.

---

### 4. Run the script

```bash
chmod +x ./update_dns.sh
./update_dns.sh
```

You’ll see output like:

```
Current IPv4: 203.0.113.12
Current IPv6: 2001:db8::1234

🔧 Starting DNS record update...
🔍 Processing AAAA record for mx1.example.com...
✅ AAAA record for mx1.example.com is up to date.
🔍 Processing TXT record for mx1.example.com...
📝 Updating TXT record for mx1.example.com → v=spf1 ip4:203.0.113.12 ip6:2001:db8::1234 mx ~all
✅ All DNS records have been processed.
```

---

## ⏱️ Automate with Cron

### Open crontab

```bash
crontab -e
```

### Automation Details
The script features an auto-location mechanism. When executed, it automatically switches to its own directory and processes environment variables in the following order:
1. System Environment Variables: If variables like CF_API_TOKEN are already defined in your system or shell, the script will use them first.
2. Automatic .env Loading: The script automatically searches for a .env file in the same directory as the script and loads its configurations.

### Usage Example
Since the script handles its own pathing, you only need to provide the absolute path to the script in your crontab.

### Example cron job (every 10 minutes)

#### Base usage:

```bash
*/10 * * * * /path/to/cloudflare-ddns-updater/update_dns.sh
```

This assumes you have already exported required environment variables (`CF_API_TOKEN`, `ZONE_NAME`, etc.) or set them inside the script.

---

#### Advanced usage with inline variables and logging:

```bash
*/10 * * * * CF_API_TOKEN=your_token ZONE_NAME=yourdomain.com AUTO_INSTALL_JQ=true /path/to/cloudflare-ddns-updater/update_dns.sh >> /var/log/cloudflare-ddns.log 2>&1
```

This version sets environment variables directly in the cron line and appends output to a log file.

---

## 🔄 Updating the Script

#### If you already cloned the repository and want to update only `update_dns.sh`:

```bash
# Go to your local repository
cd /path/to/cloudflare-ddns-updater

# Fetch the latest changes from remote
git fetch origin

# Checkout only the update_dns.sh from the remote main branch
git checkout origin/main -- update_dns.sh
```

- ✅ This replaces your local update_dns.sh with the latest version without affecting other files.

---

## 🛠 Requirements

* `bash` (v4+ recommended)
* `curl`
* `jq` (auto-installed if missing)

Manual install for `jq` on Debian/Ubuntu:

```bash
sudo apt install jq
```

---

## 📁 Project Structure

```
cloudflare-ddns-updater/
├── update_dns.sh       # Main script
├── config.conf         # DNS record configuration
├── .env.example        # Sample .env file
├── README.md           # Documentation
└── LICENSE             # MIT License
```

---

## 🔐 Cloudflare API Token Permissions

Create a scoped token with the following minimum permissions:

| Permission Type | Access |
| --------------- | ------ |
| Zone → DNS      | Edit   |
| Zone → Zone     | Read   |

Generate at: [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)

---

## ⚠️ Known Issue

Currently, if you have multiple DNS records with the same **Type** and **Name** (for example, multiple `A` records for `www`),  
the script only updates the first matched record returned by the Cloudflare API.

Cloudflare supports multiple records with the same name, and to avoid accidentally changing records managed manually or by other services,  
there is **no support yet** for selectively updating records based on the DNS record "comment" field.

This means:
- If you have multiple identical records, only one will be updated.
- You cannot yet target specific records by their Cloudflare comment.
- Use with caution if you manage multiple records for the same name.

We plan to address this in future updates to allow filtering and updating records by their comments.

---

## 📝 License

Licensed under the [MIT License](LICENSE).

---

## 🙋 Author

**[redbean0721](https://github.com/redbean0721)**

If this script is helpful, consider giving it a ⭐️ star or sharing it!
