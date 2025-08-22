<h1 align="center">3X-UI Monitor</h1>
<br>
<p align="center">A modern web interface for monitoring 3X-UI client usage statistics</p>

![Next.js](https://img.shields.io/badge/next%20js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![shadcnui](https://img.shields.io/badge/shadcn%2Fui-000000?style=for-the-badge&logo=shadcnui&logoColor=white)

## Features

* 📊 **Real-time Usage Monitoring**: View upload, download, and total usage statistics
* 🎯 **Client Identification**: Supports **_VLESS protocol only_** (UUID and V2Ray config URLs)
* 🚀 **Modern UI**: Clean, responsive interface built with Tailwind CSS
* 🔒 **Secure**: Rate limiting and input validation
* 📱 **Mobile Friendly**: Responsive design that works on all devices

## Screenshots

![Home Screenshot](https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/public/home.png)
![Usage Statistics Screenshot](https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/public/usage.png)

## Quick Installation

One-command installation (requires sudo privileges):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/install.sh)
```

The installation script will:

* Install Node.js
* Set up a systemd service
* Configure proper permissions
* Start the 3X-UI Monitor service

## Usage

1. **Open the application** in your web browser
2. **Enter your client information**:
   * VLESS protocol only
   * UUID (e.g., `12345678-1234-1234-1234-123456789012`)
   * V2Ray config URL (e.g., `vless://uuid@domain.com:443?security=tls`)
3. **View usage statistics** including:

   * Upload/Download traffic
   * Total data allowance
   * Remaining data
   * Account status and expiry

**Note**: This tool is designed to work only with the **VLESS** protocol.

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

* ✅ You can use and redistribute this software
* ✅ You must give appropriate credit to the original author
* ❌ You cannot distribute modified versions without permission

For modification requests, please contact the maintainer.

## License

This project is licensed under the Creative Commons Attribution-NoDerivs 4.0 International License (CC-BY-ND-4.0).

[![CC BY-ND 4.0](https://licensebuttons.net/l/by-nd/4.0/88x31.png)](https://creativecommons.org/licenses/by-nd/4.0/)

## Support

If you find this project useful, please consider giving it a star ⭐ on GitHub!

## Stargazers over time

[![Stargazers over time](https://starchart.cc/VikumKarunathilake/3x-ui-monitor.svg?variant=adaptive)](https://starchart.cc/VikumKarunathilake/3x-ui-monitor)

**Disclaimer**: This project is not affiliated with the official 3X-UI project. It is a third-party monitoring interface.
