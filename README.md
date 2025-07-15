
# Share 🖥️🔁📡

**Share** is a lightweight, developer-friendly tool for one-way **code syncing** between your local machine and a remote server using `rsync`. With the newly added **auto-sync** mode, it becomes the perfect companion for remote development and live deployment workflows.

---

## ✨ Key Features

- 🔁 **Auto-Sync with Watch Mode** — automatically syncs on file changes
- ⚡ Fast and efficient `rsync`-based syncing
- 🔒 SSH support with custom key and port
- 💨 Optional compression for faster transfers
- 🧹 Supports deletion of removed local files on the remote server
- 📁 Exclude common development files/folders (`node_modules`, `.git`, etc.)
- 📊 Smart change detection (mod time + size)

---

## 🚀 Usage Examples

```bash
# One-time sync
./sync.sh -s myserver.com -r /var/www/myapp

# Auto-sync with default 2s interval
./sync.sh -s myserver.com -r /var/www/myapp --watch

# Auto-sync with 5s interval
./sync.sh -s myserver.com -r /var/www/myapp --watch --interval 5

# Auto-sync with deletion and compression
./sync.sh -s myserver.com -r /var/www/myapp --watch --delete --compress
````

---

## ⚙️ Command-Line Options

| Option             | Description                                               |
| ------------------ | --------------------------------------------------------- |
| `-s`, `--server`   | Remote server address (e.g., `user@host`)                 |
| `-r`, `--remote`   | Remote path to sync to                                    |
| `-w`, `--watch`    | Enable file watching for auto-sync                        |
| `-i`, `--interval` | Watch interval in seconds (default: `2`)                  |
| `--delete`         | Delete remote files that don't exist locally              |
| `--compress`       | Enable compression during sync                            |
| `--key`            | Path to your SSH private key                              |
| `--port`           | Custom SSH port (default: `22`)                           |
| `--exclude`        | Patterns/files to exclude (repeatable or comma-separated) |

---

## 🧠 How Auto-Sync Works

1. **Initial Sync** — starts by syncing all files to the remote server.
2. **Watch Loop** — monitors the file tree periodically (default: every 2s).
3. **Change Detection** — checks file modification time and size.
4. **Smart Rsync** — syncs only the changed files using rsync delta transfers.
5. **Ctrl+C to Exit** — watch mode stops gracefully on interrupt.

---

## 📦 Requirements

* `rsync`
* `bash` or compatible shell
* `inotify-tools` or fallback polling (depending on implementation)
* SSH access to the remote server

---

## ✅ Example Use Cases

* 🔧 Remote web development (sync changes live)
* 🧪 Syncing code to cloud test environments
* 🛠️ CI/CD pre-deploy steps for staging servers
* 🌐 Quick prototyping on hosted instances

---

## 📂 Project Structure

```
share/
├── sync.sh        # Main sync script
├── README.md           # You're here!
├── .syncignore         # Optional: patterns to exclude
```

---

## 🛡️ Security & Notes

* Ensure your SSH key is secured and permissions are strict (`chmod 600`)
* Add `.env`, `node_modules`, and other non-needed folders to exclude list
* This tool is one-way sync: **local ➜ remote**

---

## 📄 License

MIT License. Use it freely, improve it, and share it back if you can! 🙌

---






