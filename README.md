## Installation (Linux)

### 🐧 Recommended: APT (Debian/Ubuntu/Zorin)

bash curl -fsSL https://hardwaremon.pages.dev/apt/setup.sh | sudo bash sudo apt install hardwaremon 

Or manually:

bash echo "deb [trusted=yes] https://hardwaremon.pages.dev/apt stable main" | sudo tee /etc/apt/sources.list.d/hardwaremon.list sudo apt update sudo apt install hardwaremon 

---

### 📦 DNF (Fedora/RHEL)

bash sudo dnf config-manager --add-repo https://hardwaremon.pages.dev/yum/hardwaremon.repo sudo dnf install hardwaremon 

---

### 🐍 PyPI (Fallback / Cross-platform)

You can still install using pip:

bash pip install hardwaremon 

Or with pipx (recommended):

bash sudo apt install pipx pipx install hardwaremon 

⚠️ Note: PyPI may not always have the latest features.  
For the best experience on Linux, use the APT or DNF repositories.

---

### 🧪 Development / Manual Run

```bash
git clone https://github.com/louisboii747/HardwareMon
cd HardwareMon
python3 hardwaremon.py
``

}
## Updating

### APT:
sudo apt update sudo apt upgrade hardwaremon 

### DNF:
sudo dnf upgrade hardwaremon 

### PyPI:
```
pipx upgrade hardwaremon
```



