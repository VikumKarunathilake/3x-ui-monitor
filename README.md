<div align="center">
  <h1 align="center">3X-UI Monitor</h1>
  <p align="center">A modern web interface for monitoring 3X-UI client usage statistics.</p>
</div>

![](https://badgen.net/badge/Next.js/000000?icon=nextjs)
![](https://badgen.net/badge/React/20232A?icon=react)
![](https://badgen.net/badge/Tailwind%20CSS/38B2AC?icon=tailwindcss)
![](https://badgen.net/badge/TypeScript/3178C6?icon=typescript)
![](https://badgen.net/badge/shadcn/ui/000000?icon=shadcnui)
![](https://badgen.net/badge/License/MIT/yellow)

## ✨ Features

*   📊 **Real-time Usage Monitoring**: View upload, download, and total usage statistics for your 3X-UI clients.
*   🎯 **Client Identification**: Easily identify clients using their UUID or V2Ray configuration URL (**VLESS protocol only**).
*   🚀 **Modern UI**: A clean and responsive user interface built with Next.js, Tailwind CSS, and shadcn/ui.
*   🔒 **Secure**: Includes rate limiting and input validation to protect your instance.
*   📱 **Mobile-First Design**: Fully responsive, ensuring a seamless experience on any device.

## 📸 Screenshots

| Home                                                                                                             | Usage Statistics                                                                                                     |
| ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| ![Home Screenshot](https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/public/home.png)         | ![Usage Statistics Screenshot](https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/public/usage.png) |

## 🚀 Getting Started

### Prerequisites

*   [Node.js](https://nodejs.org/en/) (v20.x or higher)
*   [pnpm](https://pnpm.io/installation) (or npm/yarn)

### Local Development

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/VikumKarunathilake/3x-ui-monitor.git
    cd 3x-ui-monitor
    ```

2.  **Install dependencies:**
    ```bash
    pnpm install
    ```

3.  **Run the development server:**
    ```bash
    pnpm dev
    ```

4.  Open [http://localhost:3000](http://localhost:3000) in your browser to see the result.

## 🐳 Docker

You can also build and run the application using Docker.

1.  **Build the Docker image:**
    ```bash
    docker build -t 3x-ui-monitor .
    ```

2.  **Run the Docker container:**
    ```bash
    docker run -p 3000:3000 3x-ui-monitor
    ```

## 📦 Production Installation

A one-command installation script is available for easy deployment on a Linux server.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/VikumKarunathilake/3x-ui-monitor/master/install.sh)
```

This script will:
*   Install Node.js and other required dependencies.
*   Set up and configure a `systemd` service for the application.
*   Ensure proper file permissions and ownership.
*   Start the 3X-UI Monitor service automatically.

### Systemd Service Management

The installer creates a `systemd` service to manage the application.

*   **Start the service:**
    ```bash
    sudo systemctl start 3x-ui-monitor
    ```

*   **Stop the service:**
    ```bash
    sudo systemctl stop 3x-ui-monitor
    ```

*   **Check the status:**
    ```bash
    sudo systemctl status 3x-ui-monitor
    ```

*   **View logs:**
    ```bash
    journalctl -u 3x-ui-monitor -f
    ```

## 🤝 Contributing

We welcome contributions to 3X-UI Monitor! This project is licensed under the MIT License, which means you are free to use, modify, and distribute the code.

To contribute:
1.  **Fork** the repository.
2.  **Create a new branch** for your feature or bug fix.
3.  **Make your changes** and ensure they follow the project's coding style.
4.  **Submit a pull request** with a clear description of your changes.

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for more details.

## 🙏 Support

If you find this project useful, please consider giving it a star ⭐ on GitHub!

[![Stargazers over time](https://starchart.cc/VikumKarunathilake/3x-ui-monitor.svg?variant=adaptive)](https://starchart.cc/VikumKarunathilake/3x-ui-monitor)

---

> **Disclaimer**: This project is not affiliated with the official 3X-UI project. It is a third-party monitoring interface.