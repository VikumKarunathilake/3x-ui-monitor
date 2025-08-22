# 3X-UI Monitor

A modern web interface for monitoring 3X-UI client usage statistics. Built with Next.js, TypeScript, and Tailwind CSS.

![3X-UI Monitor](https://img.shields.io/badge/3X--UI-Monitor-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-CC--BY--ND--4.0-lightgrey?style=for-the-badge)
![Node.js](https://img.shields.io/badge/Node.js-18%2B-green?style=for-the-badge)
![Next.js](https://img.shields.io/badge/Next.js-15-black?style=for-the-badge)

## Features

- 📊 **Real-time Usage Monitoring**: View upload, download, and total usage statistics
- 🎯 **Client Identification**: Support for both UUID and V2Ray config URLs
- 🚀 **Modern UI**: Clean, responsive interface built with Tailwind CSS
- 🔒 **Secure**: Rate limiting and input validation
- 📱 **Mobile Friendly**: Responsive design that works on all devices

## Quick Installation

One-command installation (requires sudo privileges):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/install.sh)
```

The installation script will:

- Install Node.js
- Set up a systemd service
- Configure proper permissions
- Start the 3X-UI Monitor service
  
## Usage

1. **Open the application** in your web browser
2. **Enter your client information**:
   - UUID (e.g., `12345678-1234-1234-1234-123456789012`)
   - V2Ray config URL (e.g., `vless://uuid@domain.com:443?security=tls`)
3. **View usage statistics** including:
   - Upload/Download traffic
   - Total data allowance
   - Remaining data
   - Account status and expiry

## Systemd Service

The installation creates a systemd service for easy management:

**Start service:**

```bash
sudo systemctl start 3x-ui-monitor
```

**Stop service:**

```bash
sudo systemctl stop 3x-ui-monitor
```

**Check status:**

```bash
sudo systemctl status 3x-ui-monitor
```

**View logs:**

```bash
journalctl -u 3x-ui-monitor -f
```

## Contributing

This project is licensed under Creative Commons Attribution-NoDerivs (CC-BY-ND). This means:

- ✅ You can use and redistribute this software
- ✅ You must give appropriate credit to the original author
- ❌ You cannot distribute modified versions without permission

For modification requests, please contact the maintainer.

## License

This project is licensed under the Creative Commons Attribution-NoDerivs 4.0 International License (CC-BY-ND-4.0).

[![CC BY-ND 4.0](https://licensebuttons.net/l/by-nd/4.0/88x31.png)](https://creativecommons.org/licenses/by-nd/4.0/)

## Support

If you find this project useful, please consider giving it a star ⭐ on GitHub!

## Stargazers over time

[![Stargazers over time](https://starchart.cc/VikumKarunathilake/3x-ui-monitor.svg?variant=adaptive)](https://starchart.cc/VikumKarunathilake/3x-ui-monitor)

**Disclaimer**: This project is not affiliated with the official 3X-UI project. It is a third-party monitoring interface.
