## About

HardwareMon is a modern system monitoring tool for Linux and Windows, designed to give a clear, real-time view of your computer’s hardware and performance.

It provides detailed insights into CPU, memory, disk, GPU, network, and system activity through both a graphical interface and command-line tools. Whether you want a clean visual overview or deeper technical information, HardwareMon makes it easy to understand what your system is doing at any moment.

On Linux, HardwareMon is distributed as a native package via APT and DNF, allowing simple installation and updates through your system’s package manager. On Windows, it is available as a standalone executable with a fully featured graphical interface.

The project focuses on performance, clarity, and ease of use — offering powerful monitoring without unnecessary complexity.


## Installation (Linux)

### 🐧 APT (Debian/Ubuntu/Zorin)
```
curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | sudo bash

sudo apt install hardwaremon 
```
Or manually:
```
echo "deb [trusted=yes] https://hardwaremon.pages.dev/apt stable main" | sudo tee /etc/apt/sources.list.d/hardwaremon.list sudo apt update sudo apt install hardwaremon 
```
---

### 📦 DNF (Fedora/RHEL)
```
sudo dnf config-manager --add-repo https://hardwaremon.pages.dev/yum/hardwaremon.repo sudo dnf install hardwaremon 
```
---

### 🐍 PyPI (Fallback / Cross-platform)

You can still install using pip:
```
pip install hardwaremon 
```

Or with pipx (recommended):
```
sudo apt install pipx pipx install hardwaremon 
```
⚠️ Note: PyPI may not always have the latest features.  
For the best experience on Linux, use the APT or DNF repositories.

---

## Updating

### APT:
```
sudo apt update sudo && apt upgrade hardwaremon
```

### DNF:
```
sudo dnf upgrade hardwaremon
```

### PyPI:
```
pipx upgrade hardwaremon
```


