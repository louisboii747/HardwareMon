from __future__ import annotations

import platform
import subprocess
import sys
import threading
import time
from datetime import datetime

import customtkinter as ctk
import psutil

VERSION = "dev"

# ── Optional GPU support ─────────────────────────────────────────────────────
try:
    import GPUtil
    GPU_AVAILABLE = True
except ImportError:
    GPU_AVAILABLE = False

# ── CTk global setup ─────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

# ═══════════════════════════════════════════════════════════════════════════
#  DESIGN TOKENS
# ═══════════════════════════════════════════════════════════════════════════
BG_BASE   = "#020308"
BG_CARD   = "#090912"
BG_CARD2  = "#0C0C18"
BG_SIDE   = "#05050D"
BORDER    = "#181828"
BORDER_H  = "#252540"

CYAN    = "#00E5FF"
PURPLE  = "#9B59FF"
ROSE    = "#FF4466"
AMBER   = "#FFB020"
EMERALD = "#00E887"
INDIGO  = "#5B6EF5"
PINK    = "#EC4899"

TEXT_PRI = "#EEEEFF"
TEXT_MID = "#7070A0"
TEXT_DIM = "#303050"

_SYS = platform.system()

# Per-metric colour mapping
METRIC_COLOR = {
    "cpu":  CYAN,
    "mem":  PURPLE,
    "disk": AMBER,
    "net":  EMERALD,
    "send": AMBER,
    "recv": EMERALD,
    "swap": INDIGO,
    "gpu":  PINK,
}


# ═══════════════════════════════════════════════════════════════════════════
#  UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════
def FF(size: int, bold: bool = False, mono: bool = False) -> tuple:
    """Cross-platform font tuple that degrades gracefully."""
    w = "bold" if bold else "normal"
    if mono:
        return ("Cascadia Code", size, w)
    if _SYS == "Windows":
        return ("Segoe UI Variable", size, w)
    elif _SYS == "Darwin":
        return ("SF Pro Display", size, w)
    else:
        return ("Ubuntu", size, w)


def blend(col: str, alpha: float, bg: tuple = (9, 9, 18)) -> str:
    """Alpha-blend `col` over `bg` to produce a flat colour string."""
    h = col.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    nr = int(bg[0] + (r - bg[0]) * alpha)
    ng = int(bg[1] + (g - bg[1]) * alpha)
    nb = int(bg[2] + (b - bg[2]) * alpha)
    return f"#{nr:02x}{ng:02x}{nb:02x}"


def lighten(col: str, factor: float = 0.4) -> str:
    h = col.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (f"#{int(r+(255-r)*factor):02x}"
            f"{int(g+(255-g)*factor):02x}"
            f"{int(b+(255-b)*factor):02x}")


def severity(pct: float) -> str:
    if pct < 60:
        return EMERALD
    if pct < 85:
        return AMBER
    return ROSE


def fmt_bytes(b: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if b < 1024:
            return f"{b:.1f} {unit}"
        b /= 1024
    return f"{b:.1f} PB"


def ease_out_cubic(t: float) -> float:
    return 1.0 - (1.0 - t) ** 3


def ease_out_quart(t: float) -> float:
    return 1.0 - (1.0 - t) ** 4


# ── CPU name, cross-platform ─────────────────────────────────────────────────
def get_cpu_name() -> str:
    # Windows registry
    try:
        import winreg
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"HARDWARE\DESCRIPTION\System\CentralProcessor\0",
        )
        name, _ = winreg.QueryValueEx(key, "ProcessorNameString")
        winreg.CloseKey(key)
        cleaned = " ".join(name.split())
        if cleaned:
            return cleaned
    except Exception:
        pass
    # Linux /proc/cpuinfo
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line.lower():
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    # macOS sysctl
    try:
        out = subprocess.check_output(
            ["sysctl", "-n", "machdep.cpu.brand_string"], text=True, timeout=1
        ).strip()
        if out:
            return out
    except Exception:
        pass
    # Fallback
    p = platform.processor().strip()
    if p and p.lower() not in ("", "unknown"):
        return p
    cp = psutil.cpu_count(logical=False) or "?"
    cl = psutil.cpu_count(logical=True) or "?"
    return f"{platform.machine()}  {cp}C / {cl}T"


# ═══════════════════════════════════════════════════════════════════════════
#  DATA STRUCTURES
# ═══════════════════════════════════════════════════════════════════════════
class RingBuffer:
    def __init__(self, size: int = 60):
        self.size = size
        self.data = [0.0] * size

    def push(self, v: float):
        self.data.pop(0)
        self.data.append(float(max(0.0, v)))

    def last(self) -> float:
        return self.data[-1]

    def peak(self) -> float:
        return max(self.data)

    def mean(self) -> float:
        return sum(self.data) / len(self.data)


# ═══════════════════════════════════════════════════════════════════════════
#  SPARKLINE CANVAS
# ═══════════════════════════════════════════════════════════════════════════
class Sparkline(ctk.CTkCanvas):
    """Smooth neon sparkline with gradient fill, glow line, and end-dot."""

    def __init__(self, master, buf: RingBuffer, color: str = CYAN,
                 bg_color: str = BG_CARD, **kw):
        super().__init__(master, bg=bg_color, highlightthickness=0, **kw)
        self.buf = buf
        self.color = color
        self._bg_color = bg_color
        self._bg_rgb = self._parse_hex(bg_color)
        self._glow = 0.0
        self.bind("<Configure>", lambda _: self._draw())

    @staticmethod
    def _parse_hex(col: str) -> tuple:
        h = col.lstrip("#")
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

    def _blend(self, alpha: float) -> str:
        return blend(self.color, alpha, self._bg_rgb)

    def _make_pts(self) -> list[float]:
        W, H = self.winfo_width(), self.winfo_height()
        data = self.buf.data
        n = len(data)
        hi = max(max(data), 1.0)
        pad = 5
        pts: list[float] = []
        for i, v in enumerate(data):
            x = i * W / max(n - 1, 1)
            y = H - pad - (v / hi) * (H - pad * 2)
            pts.extend([x, y])
        return pts

    def _draw(self):
        self.delete("all")
        W, H = self.winfo_width(), self.winfo_height()
        if W < 4 or H < 4:
            return
        pts = self._make_pts()
        if len(pts) < 4:
            return

        fill_pts = [pts[0], H] + pts + [pts[-2], H]

        # Layered gradient fill
        for a in (0.04, 0.09, 0.16):
            self.create_polygon(fill_pts, fill=self._blend(a), outline="", smooth=True)

        # Glow line (wide, soft)
        self.create_line(pts, fill=self._blend(0.30), width=5, smooth=True)
        # Crisp line on top
        self.create_line(pts, fill=self.color, width=1.5, smooth=True)

        # End-point dot
        ex, ey = pts[-2], pts[-1]
        self.create_oval(ex - 3.5, ey - 3.5, ex + 3.5, ey + 3.5,
                         fill=self.color, outline=self._bg_color, width=1.5)

    def refresh(self):
        self._draw()

    def pulse_glow(self):
        self._glow = 0.45
        self._anim_glow()

    def _anim_glow(self):
        if self._glow <= 0:
            self.delete("glow")
            return
        W, H = self.winfo_width(), self.winfo_height()
        self.delete("glow")
        self.create_rectangle(0, 0, W, H,
                              fill=self._blend(self._glow),
                              outline="", tags="glow")
        self._draw()
        self._glow -= 0.04
        self.after(18, self._anim_glow)


# ═══════════════════════════════════════════════════════════════════════════
#  ANIMATED LABEL
# ═══════════════════════════════════════════════════════════════════════════
class AnimatedLabel(ctk.CTkLabel):
    """CTkLabel that smoothly tweens its numeric value."""

    def __init__(self, master, fmt: str = "{:.1f}", suffix: str = "", **kw):
        super().__init__(master, **kw)
        self._fmt = fmt
        self._suf = suffix
        self._cur = 0.0
        self._tgt = 0.0
        self._aid: str | None = None

    def set_value(self, target: float, color: str | None = None):
        self._tgt = target
        if color:
            self.configure(text_color=color)
        self._anim()

    def _anim(self):
        if self._aid:
            self.after_cancel(self._aid)
        diff = self._tgt - self._cur
        if abs(diff) < 0.08:
            self._cur = self._tgt
            self._render()
            return
        self._cur += diff * 0.26
        self._render()
        self._aid = self.after(16, self._anim)

    def _render(self):
        try:
            self.configure(text=self._fmt.format(self._cur) + self._suf)
        except Exception:
            pass


# ═══════════════════════════════════════════════════════════════════════════
#  ARC GAUGE
# ═══════════════════════════════════════════════════════════════════════════
class ArcGauge(ctk.CTkCanvas):
    """Animated circular gauge: track ring + coloured value arc + centre text."""

    SWEEP = 270   # degrees of arc sweep

    def __init__(self, master, size: int = 92, color: str = CYAN,
                 bg_color: str = BG_CARD, **kw):
        super().__init__(master, width=size, height=size,
                         bg=bg_color, highlightthickness=0, **kw)
        self._size = size
        self._color = color
        self._val = 0.0
        self._tgt = 0.0
        self._aid: str | None = None
        self._draw(0.0)

    def set(self, pct: float, color: str | None = None):
        if color:
            self._color = color
        self._tgt = max(0.0, min(100.0, pct))
        self._anim()

    def _anim(self):
        if self._aid:
            self.after_cancel(self._aid)
        diff = self._tgt - self._val
        if abs(diff) < 0.35:
            self._val = self._tgt
            self._draw(self._val)
            return
        self._val += diff * 0.22
        self._draw(self._val)
        self._aid = self.after(16, self._anim)

    def _draw(self, pct: float):
        self.delete("all")
        s = self._size
        pad = 9
        x0, y0, x1, y1 = pad, pad, s - pad, s - pad

        # Background track
        self.create_arc(x0, y0, x1, y1,
                        start=225, extent=-(self.SWEEP),
                        style="arc", outline=BORDER_H, width=8)

        # Value arc
        ext = -(self.SWEEP * pct / 100)
        if abs(ext) > 1:
            col = self._color
            # Soft glow ring
            self.create_arc(x0 - 2, y0 - 2, x1 + 2, y1 + 2,
                            start=225, extent=ext,
                            style="arc", outline=lighten(col, 0.3), width=3)
            # Main arc
            self.create_arc(x0, y0, x1, y1,
                            start=225, extent=ext,
                            style="arc", outline=col, width=8)

        # Centre text
        cx, cy = s // 2, s // 2
        self.create_text(cx, cy - 3,
                         text=f"{pct:.0f}",
                         fill=TEXT_PRI, font=FF(16, bold=True))
        self.create_text(cx, cy + 14,
                         text="%",
                         fill=TEXT_MID, font=FF(8))


# ═══════════════════════════════════════════════════════════════════════════
#  METRIC CARD
# ═══════════════════════════════════════════════════════════════════════════
class MetricCard(ctk.CTkFrame):
    """Neon card: header + (big-number | gauge) + sparkline footer."""

    def __init__(self, master, title: str, icon: str, buf: RingBuffer,
                 color: str = CYAN, unit: str = "%", **kw):
        super().__init__(master,
                         fg_color=BG_CARD,
                         corner_radius=16,
                         border_width=1,
                         border_color=BORDER,
                         **kw)
        self.buf = buf
        self.unit = unit
        self.color = color
        self._prev = 0.0

        # ── Header ────────────────────────────────────────────────────────
        hdr = ctk.CTkFrame(self, fg_color="transparent")
        hdr.pack(fill="x", padx=16, pady=(14, 0))

        icon_lbl = ctk.CTkLabel(hdr, text=icon, font=("Segoe UI Emoji", 16),
                                text_color=color)
        icon_lbl.pack(side="left")

        ctk.CTkLabel(hdr, text=title, font=FF(11, bold=True),
                     text_color=TEXT_PRI).pack(side="left", padx=(8, 0))

        self.peak_lbl = ctk.CTkLabel(hdr, text="peak —",
                                     font=FF(9), text_color=TEXT_DIM)
        self.peak_lbl.pack(side="right")

        # Accent separator
        sep = ctk.CTkFrame(self, fg_color=color, height=1, corner_radius=1)
        sep.pack(fill="x", padx=16, pady=(6, 0))
        self._dim_sep(sep, color)

        # ── Body: big-number (left) + gauge (right) ───────────────────────
        body = ctk.CTkFrame(self, fg_color="transparent")
        body.pack(fill="x", padx=16, pady=(10, 0))

        num_col = ctk.CTkFrame(body, fg_color="transparent")
        num_col.pack(side="left", fill="both", expand=True)

        fmt = "{:.0f}" if unit in (" KB/s", " MB/s", " B/s") else "{:.1f}"
        self.val_lbl = AnimatedLabel(
            num_col, fmt=fmt, suffix=unit,
            font=FF(28, bold=True), text=f"0{unit}",
            text_color=TEXT_PRI,
        )
        self.val_lbl.pack(anchor="w")

        self.sub_lbl = ctk.CTkLabel(num_col, text="",
                                    font=FF(9), text_color=TEXT_MID)
        self.sub_lbl.pack(anchor="w", pady=(2, 0))

        self.gauge = ArcGauge(body, size=88, color=color, bg_color=BG_CARD)
        self.gauge.pack(side="right")

        # ── Sparkline footer ──────────────────────────────────────────────
        self.spark = Sparkline(self, buf=buf, color=color,
                               bg_color=BG_CARD, height=48)
        self.spark.pack(fill="x", padx=12, pady=(10, 12))

        # Entrance animation
        self.after(30, lambda: self._entrance(sep, color))

    def _dim_sep(self, sep: ctk.CTkFrame, color: str):
        """Fade the separator from accent to border."""
        steps = [(color, 60), (blend(color, 0.5), 60), (BORDER, 0)]

        def s(i=0):
            if i < len(steps):
                c, delay = steps[i]
                try:
                    sep.configure(fg_color=c)
                except Exception:
                    pass
                if delay:
                    self.after(delay, lambda: s(i + 1))

        self.after(400, lambda: s())

    def _entrance(self, sep: ctk.CTkFrame, color: str):
        """Quick border flash on mount."""
        seq = [color, blend(color, 0.5), BORDER]

        def s(i=0):
            if i < len(seq):
                try:
                    self.configure(border_color=seq[i])
                except Exception:
                    pass
                self.after(100, lambda: s(i + 1))

        s()

    def update_data(self, pct: float, sub: str = ""):
        col = severity(pct) if self.unit == "%" else self.color
        self.val_lbl.set_value(pct, color=col if self.unit == "%" else TEXT_PRI)
        self.sub_lbl.configure(text=sub)
        self.gauge.set(pct if self.unit == "%" else min(pct / max(self.buf.peak(), 1) * 100, 100),
                       color=col)
        self.spark.refresh()
        pk = self.buf.peak()
        self.peak_lbl.configure(text=f"peak {pk:.0f}{self.unit}")
        if abs(pct - self._prev) > 14:
            self.spark.pulse_glow()
        self._prev = pct


# ═══════════════════════════════════════════════════════════════════════════
#  INFO PANEL
# ═══════════════════════════════════════════════════════════════════════════
class InfoPanel(ctk.CTkScrollableFrame):
    """Key-value info rows, grouped under section headers."""

    def __init__(self, master, **kw):
        super().__init__(master,
                         fg_color="transparent",
                         scrollbar_button_color=BORDER_H,
                         scrollbar_button_hover_color=CYAN,
                         **kw)
        self._rows: dict[str, ctk.CTkLabel] = {}
        self._sections: set[str] = set()

    def set_section(self, title: str):
        if title in self._sections:
            return
        self._sections.add(title)
        # Section title
        hdr_row = ctk.CTkFrame(self, fg_color="transparent")
        hdr_row.pack(fill="x", padx=4, pady=(14, 0))
        dot = ctk.CTkFrame(hdr_row, fg_color=CYAN, width=3, height=12, corner_radius=2)
        dot.pack(side="left", padx=(0, 8))
        ctk.CTkLabel(hdr_row, text=title.upper(),
                     font=FF(9, bold=True), text_color=CYAN).pack(side="left")
        sep = ctk.CTkFrame(self, fg_color=BORDER_H, height=1)
        sep.pack(fill="x", padx=4, pady=(4, 2))

    def set_row(self, key: str, value: str, key_id: str = ""):
        rid = key_id or key
        if rid in self._rows:
            self._rows[rid].configure(text=value)
            return
        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(fill="x", padx=4, pady=2)
        ctk.CTkLabel(row, text=key, font=FF(10), text_color=TEXT_MID,
                     width=140, anchor="w").pack(side="left")
        lbl = ctk.CTkLabel(row, text=value, font=FF(10, bold=True),
                           text_color=TEXT_PRI, anchor="w")
        lbl.pack(side="left")
        self._rows[rid] = lbl


# ═══════════════════════════════════════════════════════════════════════════
#  PROCESS TABLE
# ═══════════════════════════════════════════════════════════════════════════
class ProcessTable(ctk.CTkFrame):
    """Scrollable top-processes table with zebra rows and colour-coded CPU %."""

    COLS = [("Process", 190), ("PID", 60), ("CPU %", 65), ("RAM", 75)]

    def __init__(self, master, **kw):
        super().__init__(master,
                         fg_color=BG_CARD,
                         corner_radius=16,
                         border_width=1,
                         border_color=BORDER,
                         **kw)
        # Header bar
        hdr = ctk.CTkFrame(self, fg_color="transparent")
        hdr.pack(fill="x", padx=16, pady=(12, 0))
        ctk.CTkLabel(hdr, text="⚙  Top Processes",
                     font=FF(11, bold=True), text_color=TEXT_PRI).pack(side="left")

        # Column labels
        col_bar = ctk.CTkFrame(self, fg_color=BG_CARD2, corner_radius=8)
        col_bar.pack(fill="x", padx=16, pady=(6, 0))
        for name, w in self.COLS:
            ctk.CTkLabel(col_bar, text=name, width=w,
                         font=FF(9, bold=True), text_color=TEXT_MID,
                         anchor="w").pack(side="left", padx=6, pady=4)

        self.body = ctk.CTkScrollableFrame(
            self, fg_color="transparent", height=150,
            scrollbar_button_color=BORDER_H,
            scrollbar_button_hover_color=CYAN,
        )
        self.body.pack(fill="x", padx=16, pady=(2, 12))

    def refresh(self, procs: list[dict]):
        for w in self.body.winfo_children():
            w.destroy()
        for i, p in enumerate(procs[:12]):
            bg = BG_CARD2 if i % 2 == 0 else "transparent"
            row = ctk.CTkFrame(self.body, fg_color=bg, corner_radius=6)
            row.pack(fill="x", pady=1)
            name = (p["name"][:24] + "…") if len(p["name"]) > 25 else p["name"]
            mem_str = fmt_bytes(p["mem"] * 1024 * 1024)
            data = [name, str(p["pid"]), f"{p['cpu']:.1f}%", mem_str]
            widths = [190, 60, 65, 75]
            colors = [TEXT_PRI, TEXT_MID, severity(p["cpu"]), TEXT_PRI]
            for val, w, c in zip(data, widths, colors):
                ctk.CTkLabel(row, text=val, width=w, font=FF(9),
                             text_color=c, anchor="w").pack(side="left", padx=6, pady=3)


# ═══════════════════════════════════════════════════════════════════════════
#  SIDEBAR NAV BUTTON
# ═══════════════════════════════════════════════════════════════════════════
class NavButton(ctk.CTkButton):
    def __init__(self, master, text: str, icon: str, command, **kw):
        super().__init__(
            master,
            text=f"   {icon}   {text}",
            font=FF(12),
            fg_color="transparent",
            hover_color=blend(CYAN, 0.06, (5, 5, 13)),
            text_color=TEXT_MID,
            anchor="w",
            height=40,
            corner_radius=10,
            command=command,
            **kw,
        )

    def set_active(self, active: bool):
        if active:
            self.configure(
                fg_color=blend(CYAN, 0.08, (5, 5, 13)),
                text_color=CYAN,
                border_color=blend(CYAN, 0.3),
                border_width=1,
            )
        else:
            self.configure(
                fg_color="transparent",
                text_color=TEXT_MID,
                border_width=0,
            )


# ═══════════════════════════════════════════════════════════════════════════
#  MAIN APPLICATION
# ═══════════════════════════════════════════════════════════════════════════
class HardwareMonApp(ctk.CTk):
    PAGES = ["Overview", "CPU", "Memory", "Disk", "Network", "System"]
    ICONS = {
        "Overview": "⬡",
        "CPU": "▣",
        "Memory": "◈",
        "Disk": "⬤",
        "Network": "◉",
        "System": "◇",
    }

    def __init__(self):
        super().__init__()
        self.title("HardwareMon")
        self.geometry("1120x720")
        self.minsize(920, 600)
        self.configure(fg_color=BG_BASE)

        # ── Ring buffers ─────────────────────────────────────────────────
        self.cpu_buf       = RingBuffer(60)
        self.mem_buf       = RingBuffer(60)
        self.disk_buf      = RingBuffer(60)
        self.net_buf       = RingBuffer(60)
        self.swap_buf      = RingBuffer(60)
        self.net_send_buf  = RingBuffer(60)
        self.net_recv_buf  = RingBuffer(60)

        # ── State ────────────────────────────────────────────────────────
        self._current_page: str = "Overview"
        self._transitioning: bool = False
        self._nav_buttons: dict[str, NavButton] = {}
        self._pages: dict[str, ctk.CTkFrame] = {}
        self._cpu_name = get_cpu_name()
        self._prev_net = psutil.net_io_counters()
        self._prev_net_time = time.time()
        self._prev_disk = psutil.disk_io_counters()
        self._prev_disk_time = time.time()
        self._disk_cache: list = []
        self._disk_tick = 0
        self._thread_count = 0
        self._thread_tick = 0
        self._nav_pill_y: float = 0.0
        self._nav_pill_aid: str | None = None
        self._nav_btn_ys: dict[str, int] = {}
        self._start_time = datetime.now()

        self._build_layout()
        self._build_sidebar()
        self._build_all_pages()
        # Position all pages via place then show first
        self._init_page_placement()

        self._running = True
        t = threading.Thread(target=self._data_loop, daemon=True)
        t.start()

    # ══════════════════════════════════════════════════════════════════════
    #  LAYOUT SKELETON
    # ══════════════════════════════════════════════════════════════════════
    def _build_layout(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(1, weight=1)

        # ── Top bar ───────────────────────────────────────────────────────
        self.topbar = ctk.CTkFrame(self, fg_color=BG_CARD,
                                   corner_radius=0, height=50)
        self.topbar.grid(row=0, column=0, columnspan=2, sticky="ew")
        self.topbar.grid_propagate(False)

        # Logo
        ctk.CTkLabel(self.topbar, text="⬡  HardwareMon",
                     font=FF(14, bold=True), text_color=CYAN).pack(
            side="left", padx=20)

        # Right cluster
        self.time_lbl = ctk.CTkLabel(self.topbar, text="",
                                     font=FF(9), text_color=TEXT_MID)
        self.time_lbl.pack(side="right", padx=20)

        self.live_dot = ctk.CTkLabel(self.topbar, text="● LIVE",
                                     font=FF(10, bold=True), text_color=EMERALD)
        self.live_dot.pack(side="right", padx=(0, 4))

        self.uptime_lbl = ctk.CTkLabel(self.topbar, text="up 0s",
                                       font=FF(9), text_color=TEXT_DIM)
        self.uptime_lbl.pack(side="right", padx=(0, 20))

        # Accent line under topbar
        accent_line = ctk.CTkFrame(self, fg_color=blend(CYAN, 0.25), height=1)
        accent_line.grid(row=0, column=0, columnspan=2, sticky="sew")

        # ── Sidebar ───────────────────────────────────────────────────────
        self.sidebar = ctk.CTkFrame(self, fg_color=BG_SIDE,
                                    corner_radius=0, width=192)
        self.sidebar.grid(row=1, column=0, sticky="nsew")
        self.sidebar.grid_propagate(False)

        # Sidebar right edge separator
        side_sep = ctk.CTkFrame(self.sidebar, fg_color=BORDER,
                                width=1, height=2000, corner_radius=0)
        side_sep.place(relx=1.0, rely=0, x=-1)

        # ── Content ───────────────────────────────────────────────────────
        self.content = ctk.CTkFrame(self, fg_color="transparent")
        self.content.grid(row=1, column=1, sticky="nsew")
        self.content.grid_propagate(False)

        # Start animations
        self.after(600, self._pulse_live)

    # ══════════════════════════════════════════════════════════════════════
    #  SIDEBAR
    # ══════════════════════════════════════════════════════════════════════
    def _build_sidebar(self):
        ctk.CTkLabel(self.sidebar, text="NAVIGATION",
                     font=FF(8, bold=True), text_color=TEXT_DIM).pack(
            anchor="w", padx=18, pady=(20, 6))

        # Animated pill indicator
        self._nav_pill = ctk.CTkFrame(
            self.sidebar,
            fg_color=CYAN,
            corner_radius=2,
            width=3,
            height=36
        )

        self._nav_pill.place(x=0, y=70)

        for page in self.PAGES:
            icon = self.ICONS.get(page, "◆")
            btn = NavButton(self.sidebar, page, icon,
                            command=lambda p=page: self._show_page(p))
            btn.pack(fill="x", padx=10, pady=2)
            self._nav_buttons[page] = btn

        # Version footer
        os_line = f"{_SYS} · {platform.release()}"
        ctk.CTkLabel(self.sidebar,
                     text=f"v{VERSION}\n{os_line}",
                     font=FF(8), text_color=TEXT_DIM,
                     justify="center").pack(side="bottom", pady=14)

        # Read button y-positions after layout settles
        self.after(150, self._init_nav_pill)

    def _init_nav_pill(self):
        for name, btn in self._nav_buttons.items():
            y = btn.winfo_y() + (btn.winfo_height() - 36) // 2
            self._nav_btn_ys[name] = y
        self._nav_pill_y = float(self._nav_btn_ys.get("Overview", 70))
        self._nav_pill.place(x=0, y=int(self._nav_pill_y))

    def _animate_nav_pill(self, page: str):
        target_y = float(self._nav_btn_ys.get(page, self._nav_pill_y))
        if self._nav_pill_aid:
            self.after_cancel(self._nav_pill_aid)

        def tick():
            diff = target_y - self._nav_pill_y
            if abs(diff) < 0.5:
                self._nav_pill_y = target_y
                self._nav_pill.place(x=0, y=int(target_y))
                return
            self._nav_pill_y += diff * 0.28
            self._nav_pill.place(x=0, y=int(self._nav_pill_y))
            self._nav_pill_aid = self.after(14, tick)

        tick()

    # ══════════════════════════════════════════════════════════════════════
    #  PAGE TRANSITIONS  (pure place geometry — no grid mixing)
    # ══════════════════════════════════════════════════════════════════════
    def _init_page_placement(self):
        """Park all pages off-screen to the right, show Overview."""
        for name, frame in self._pages.items():
            frame.place(relx=1.0, rely=0.0, relwidth=1.0, relheight=1.0)
        self._pages["Overview"].place(relx=0.0, rely=0.0, relwidth=1.0, relheight=1.0)
        self._nav_buttons["Overview"].set_active(True)

    def _show_page(self, name: str):
        if name == self._current_page or self._transitioning:
            return

        old_idx = self.PAGES.index(self._current_page)
        new_idx = self.PAGES.index(name)
        direction = 1 if new_idx > old_idx else -1

        old_frame = self._pages[self._current_page]
        new_frame = self._pages[name]

        self._transitioning = True
        self._current_page = name

        # Update nav
        for n, btn in self._nav_buttons.items():
            btn.set_active(n == name)
        self._animate_nav_pill(name)

        # Flash topbar accent
        self._flash_topbar()

        # Park new frame off to the correct side, then animate
        new_frame.place(relx=direction, rely=0.0, relwidth=1.0, relheight=1.0)
        new_frame.lift()

        self._run_transition(old_frame, new_frame, direction)

    def _run_transition(self, old_frame: ctk.CTkFrame, new_frame: ctk.CTkFrame,
                        direction: int, steps: int = 14, delay: int = 13):
        step = [0]

        def tick():
            step[0] += 1
            if step[0] >= steps:
                new_frame.place(relx=0.0, rely=0.0, relwidth=1.0, relheight=1.0)
                # Park old frame far off-screen
                old_frame.place(relx=direction * 3, rely=0.0,
                                relwidth=1.0, relheight=1.0)
                self._transitioning = False
                return
            t = ease_out_quart(step[0] / steps)
            new_frame.place(relx=direction * (1.0 - t), rely=0.0,
                            relwidth=1.0, relheight=1.0)
            old_frame.place(relx=-direction * t, rely=0.0,
                            relwidth=1.0, relheight=1.0)
            self.after(delay, tick)

        tick()

    def _flash_topbar(self):
        seq = [blend(CYAN, 0.15, (9, 9, 18)), blend(CYAN, 0.08, (9, 9, 18)), BG_CARD]

        def s(i=0):
            if i < len(seq):
                try:
                    self.topbar.configure(fg_color=seq[i])
                except Exception:
                    pass
                self.after(55, lambda: s(i + 1))

        s()

    def _pulse_live(self):
        pulses = [EMERALD, blend(EMERALD, 0.3), EMERALD, blend(EMERALD, 0.3), EMERALD]

        def s(i=0):
            if i < len(pulses):
                try:
                    self.live_dot.configure(text_color=pulses[i])
                except Exception:
                    pass
                self.after(200, lambda: s(i + 1))
            else:
                self.after(2500, self._pulse_live)

        s()

    # ══════════════════════════════════════════════════════════════════════
    #  PAGE BUILDERS
    # ══════════════════════════════════════════════════════════════════════
    def _build_all_pages(self):
        for page in self.PAGES:
            frame = ctk.CTkFrame(self.content, fg_color="transparent")
            self._pages[page] = frame

        self._build_overview()
        self._build_cpu_page()
        self._build_memory_page()
        self._build_disk_page()
        self._build_network_page()
        self._build_system_page()

    # ── Overview ──────────────────────────────────────────────────────────
    def _build_overview(self):
        p = self._pages["Overview"]
        p.grid_columnconfigure((0, 1, 2, 3), weight=1)
        p.grid_rowconfigure(2, weight=1)

        self._page_title(p, "Overview", "System at a glance", col_span=4)

        self.ov_cpu  = MetricCard(p, "CPU Usage",  "▣", self.cpu_buf,  METRIC_COLOR["cpu"])
        self.ov_mem  = MetricCard(p, "Memory",     "◈", self.mem_buf,  METRIC_COLOR["mem"])
        self.ov_disk = MetricCard(p, "Disk I/O",   "⬤", self.disk_buf, METRIC_COLOR["disk"],
                                  unit=" MB/s")
        self.ov_net  = MetricCard(p, "Network ↓",  "◉", self.net_buf,  METRIC_COLOR["recv"],
                                  unit=" KB/s")

        for i, card in enumerate([self.ov_cpu, self.ov_mem, self.ov_disk, self.ov_net]):
            px_l = 12 if i == 0 else 5
            px_r = 12 if i == 3 else 5
            card.grid(row=1, column=i, padx=(px_l, px_r), pady=(0, 8), sticky="nsew")

        self.proc_table = ProcessTable(p)
        self.proc_table.grid(row=2, column=0, columnspan=4,
                             padx=12, pady=(0, 12), sticky="nsew")

    # ── CPU ───────────────────────────────────────────────────────────────
    def _build_cpu_page(self):
        p = self._pages["CPU"]
        p.grid_columnconfigure(0, weight=2)
        p.grid_columnconfigure(1, weight=1)
        p.grid_rowconfigure(1, weight=1)

        self._page_title(p, "CPU", "Per-core load & details", col_span=2)

        # Per-core frame
        self.core_outer = ctk.CTkFrame(p, fg_color=BG_CARD,
                                       corner_radius=16, border_width=1,
                                       border_color=BORDER)
        self.core_outer.grid(row=1, column=0, padx=(12, 5), pady=(0, 12), sticky="nsew")
        ctk.CTkLabel(self.core_outer, text="Per-Core Utilisation",
                     font=FF(11, bold=True), text_color=TEXT_PRI).pack(
            anchor="w", padx=16, pady=(12, 4))

        self.core_scroll = ctk.CTkScrollableFrame(
            self.core_outer, fg_color="transparent",
            scrollbar_button_color=BORDER_H,
            scrollbar_button_hover_color=CYAN,
        )
        self.core_scroll.pack(fill="both", expand=True, padx=8, pady=(0, 8))
        self._core_bars: list = []

        n = psutil.cpu_count(logical=True) or 1
        cols = 2 if n <= 8 else 4

        for i in range(n):
            r, c = divmod(i, cols)
            cell = ctk.CTkFrame(self.core_scroll, fg_color="transparent")
            cell.grid(row=r, column=c, padx=6, pady=4, sticky="ew")
            self.core_scroll.grid_columnconfigure(c, weight=1)

            ctk.CTkLabel(cell, text=f"C{i:02d}", width=28,
                         font=FF(9, bold=True), text_color=TEXT_MID).pack(side="left")
            bar = ctk.CTkProgressBar(cell, height=7, corner_radius=4,
                                     fg_color=BORDER_H, progress_color=CYAN)
            bar.set(0)
            bar.pack(side="left", fill="x", expand=True, padx=5)
            pct_lbl = ctk.CTkLabel(cell, text="0%", width=34,
                                   font=FF(9, mono=True), text_color=TEXT_MID)
            pct_lbl.pack(side="left")
            self._core_bars.append((bar, pct_lbl))
            self.after(200 + i * 35, lambda b=bar: self._shimmer(b))

        # Info panel
        self.cpu_info = InfoPanel(p)
        self.cpu_info.grid(row=1, column=1, padx=(0, 12), pady=(0, 12), sticky="nsew")

    # ── Memory ────────────────────────────────────────────────────────────
    def _build_memory_page(self):
        p = self._pages["Memory"]
        p.grid_columnconfigure((0, 1), weight=1)
        p.grid_rowconfigure(2, weight=1)

        self._page_title(p, "Memory", "RAM & page file", col_span=2)

        self.ram_card  = MetricCard(p, "RAM",       "◈", self.mem_buf,  METRIC_COLOR["mem"])
        self.swap_card = MetricCard(p, "Page File", "◻", self.swap_buf, METRIC_COLOR["swap"],
                                    unit="%")
        self.ram_card.grid(row=1, column=0, padx=(12, 5), pady=(0, 8), sticky="nsew")
        self.swap_card.grid(row=1, column=1, padx=(5, 12), pady=(0, 8), sticky="nsew")

        self.mem_info = InfoPanel(p)
        self.mem_info.grid(row=2, column=0, columnspan=2,
                           padx=12, pady=(0, 12), sticky="nsew")

    # ── Disk ──────────────────────────────────────────────────────────────
    def _build_disk_page(self):
        p = self._pages["Disk"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_rowconfigure(2, weight=1)

        self._page_title(p, "Disk", "Partitions & I/O rate", col_span=1)

        # I/O rate card
        self.disk_io_card = MetricCard(p, "Disk I/O", "⬤", self.disk_buf,
                                       METRIC_COLOR["disk"], unit=" MB/s")
        self.disk_io_card.grid(row=1, column=0, padx=12, pady=(0, 8), sticky="ew")

        self.disk_parts_frame = ctk.CTkScrollableFrame(
            p, fg_color="transparent",
            scrollbar_button_color=BORDER_H,
            scrollbar_button_hover_color=AMBER,
        )
        self.disk_parts_frame.grid(row=2, column=0, padx=12, pady=(0, 12), sticky="nsew")

    # ── Network ───────────────────────────────────────────────────────────
    def _build_network_page(self):
        p = self._pages["Network"]
        p.grid_columnconfigure((0, 1), weight=1)
        p.grid_rowconfigure(2, weight=1)

        self._page_title(p, "Network", "Bandwidth & interface stats", col_span=2)

        self.net_send_card = MetricCard(p, "Upload ↑",   "◉", self.net_send_buf,
                                        METRIC_COLOR["send"], unit=" KB/s")
        self.net_recv_card = MetricCard(p, "Download ↓", "◉", self.net_recv_buf,
                                        METRIC_COLOR["recv"], unit=" KB/s")
        self.net_send_card.grid(row=1, column=0, padx=(12, 5), pady=(0, 8), sticky="nsew")
        self.net_recv_card.grid(row=1, column=1, padx=(5, 12), pady=(0, 8), sticky="nsew")

        self.net_info = InfoPanel(p)
        self.net_info.grid(row=2, column=0, columnspan=2,
                           padx=12, pady=(0, 12), sticky="nsew")

    # ── System ────────────────────────────────────────────────────────────
    def _build_system_page(self):
        p = self._pages["System"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_rowconfigure(1, weight=1)

        self._page_title(p, "System Information", "Hardware & software details", col_span=1)

        self.sys_info = InfoPanel(p)
        self.sys_info.grid(row=1, column=0, padx=12, pady=(0, 12), sticky="nsew")
        self._populate_system_info()

    def _populate_system_info(self):
        inf = self.sys_info
        inf.set_section("Operating System")
        inf.set_row("OS", f"{platform.system()} {platform.release()}")
        inf.set_row("Version", platform.version()[:64])
        inf.set_row("Machine", platform.machine())
        inf.set_row("Hostname", platform.node())

        inf.set_section("Processor")
        inf.set_row("Name", self._cpu_name[:64])
        inf.set_row("Physical cores", str(psutil.cpu_count(logical=False)))
        inf.set_row("Logical cores", str(psutil.cpu_count(logical=True)))
        try:
            freq = psutil.cpu_freq()
            if freq:
                inf.set_row("Max frequency", f"{freq.max:.0f} MHz")
                inf.set_row("Base frequency", f"{freq.min:.0f} MHz")
        except Exception:
            pass

        inf.set_section("Memory")
        vm = psutil.virtual_memory()
        sw = psutil.swap_memory()
        inf.set_row("Total RAM", fmt_bytes(vm.total))
        inf.set_row("Page file total", fmt_bytes(sw.total))

        if GPU_AVAILABLE:
            try:
                gpus = GPUtil.getGPUs()
                if gpus:
                    inf.set_section("GPU")
                    for i, gpu in enumerate(gpus):
                        inf.set_row(f"GPU {i}", gpu.name)
                        inf.set_row("VRAM", f"{gpu.memoryTotal:.0f} MB")
                        inf.set_row("Driver", gpu.driver)
            except Exception:
                pass

        inf.set_section("Python")
        inf.set_row("Version", sys.version[:48])
        inf.set_row("Executable", sys.executable[:64])

    # ══════════════════════════════════════════════════════════════════════
    #  HELPER WIDGETS
    # ══════════════════════════════════════════════════════════════════════
    def _page_title(self, parent, title: str, subtitle: str = "", col_span: int = 1):
        row = ctk.CTkFrame(parent, fg_color="transparent")
        row.grid(row=0, column=0, columnspan=col_span,
                 sticky="ew", padx=16, pady=(16, 10))
        ctk.CTkLabel(row, text=title,
                     font=FF(22, bold=True), text_color=TEXT_PRI).pack(side="left")
        if subtitle:
            ctk.CTkLabel(row, text=f"  ·  {subtitle}",
                         font=FF(12), text_color=TEXT_MID).pack(side="left", pady=(6, 0))

    def _shimmer(self, bar: ctk.CTkProgressBar):
        """Boot-time shimmer sweep on a progress bar."""
        val = [0.0]
        up = [True]

        def tick():
            if up[0]:
                val[0] = min(val[0] + 0.06, 1.0)
                if val[0] >= 1.0:
                    up[0] = False
            else:
                val[0] = max(val[0] - 0.06, 0.0)
                if val[0] <= 0.0:
                    return
            try:
                bar.set(val[0])
                bar.configure(progress_color=CYAN)
            except Exception:
                return
            self.after(16, tick)

        tick()

    # ══════════════════════════════════════════════════════════════════════
    #  DATA LOOP  (background thread)
    # ══════════════════════════════════════════════════════════════════════
    def _data_loop(self):
        # Prime cpu_percent
        psutil.cpu_percent(interval=None)
        psutil.cpu_percent(percpu=True)
        while self._running:
            try:
                self._collect()
            except Exception:
                pass
            time.sleep(1)

    def _collect(self):
        # CPU
        cpu_pct    = psutil.cpu_percent(interval=None)
        core_pcts  = psutil.cpu_percent(percpu=True)
        self.cpu_buf.push(cpu_pct)

        # Memory
        vm = psutil.virtual_memory()
        sw = psutil.swap_memory()
        self.mem_buf.push(vm.percent)
        self.swap_buf.push(sw.percent)

        # Disk I/O rate
        disk_mb = 0.0
        try:
            now = time.time()
            dio = psutil.disk_io_counters()
            dt = max(now - self._prev_disk_time, 0.001)
            delta = ((dio.read_bytes - self._prev_disk.read_bytes) +
                     (dio.write_bytes - self._prev_disk.write_bytes))
            disk_mb = max(delta / dt / 1048576, 0.0)
            self._prev_disk = dio
            self._prev_disk_time = now
        except Exception:
            pass
        self.disk_buf.push(disk_mb)

        # Network
        now = time.time()
        net = psutil.net_io_counters()
        dt = max(now - self._prev_net_time, 0.001)
        sent_ks = max((net.bytes_sent - self._prev_net.bytes_sent) / dt / 1024, 0.0)
        recv_ks = max((net.bytes_recv - self._prev_net.bytes_recv) / dt / 1024, 0.0)
        self._prev_net = net
        self._prev_net_time = now
        self.net_buf.push(recv_ks)
        self.net_send_buf.push(sent_ks)
        self.net_recv_buf.push(recv_ks)

        # Processes (lightweight)
        procs = []
        for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
            try:
                info = proc.info
                procs.append({
                    "pid":  info["pid"],
                    "name": info["name"] or "—",
                    "cpu":  info["cpu_percent"] or 0.0,
                    "mem":  (info["memory_info"].rss / 1048576
                             if info["memory_info"] else 0.0),
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        procs.sort(key=lambda x: x["cpu"], reverse=True)

        # Disk partitions (cached every 10 ticks)
        self._disk_tick += 1
        if self._disk_tick >= 10 or not self._disk_cache:
            parts = []
            for part in psutil.disk_partitions():
                # Skip virtual/loop filesystems
                if part.fstype in ("", "squashfs", "tmpfs", "devtmpfs"):
                    continue
                if "/snap/" in part.mountpoint or "/proc" in part.mountpoint:
                    continue
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    parts.append({
                        "device":     part.device,
                        "mountpoint": part.mountpoint,
                        "fstype":     part.fstype,
                        "total":      usage.total,
                        "used":       usage.used,
                        "free":       usage.free,
                        "pct":        usage.percent,
                    })
                except Exception:
                    pass
            self._disk_cache = parts
            self._disk_tick = 0

        # CPU freq
        try:
            freq = psutil.cpu_freq()
        except Exception:
            freq = None

        # Thread count (cached every 5 ticks)
        self._thread_tick += 1
        if self._thread_tick >= 5:
            try:
                self._thread_count = sum(
                    p.num_threads() for p in psutil.process_iter()
                )
            except Exception:
                pass
            self._thread_tick = 0

        self.after(0, self._update_ui,
                   cpu_pct, core_pcts, vm, sw, sent_ks, recv_ks,
                   net, procs, self._disk_cache, freq, disk_mb)
        self.after(0, self._update_clock)

    # ══════════════════════════════════════════════════════════════════════
    #  UI UPDATE  (main thread via after(0, ...))
    # ══════════════════════════════════════════════════════════════════════
    def _update_clock(self):
        self.time_lbl.configure(
            text=datetime.now().strftime("%a %d %b %Y  %H:%M:%S")
        )
        delta = datetime.now() - self._start_time
        h, rem = divmod(int(delta.total_seconds()), 3600)
        m, s = divmod(rem, 60)
        up = f"{h}h {m}m {s}s" if h else (f"{m}m {s}s" if m else f"{s}s")
        self.uptime_lbl.configure(text=f"up {up}")

    def _update_ui(self, cpu_pct, core_pcts, vm, sw,
                   sent_ks, recv_ks, net, procs, parts, freq, disk_mb):

        # ── Overview ────────────────────────────────────────────────────
        freq_str = f"{freq.current:.0f} MHz" if freq else "— MHz"
        self.ov_cpu.update_data(
            cpu_pct,
            f"{psutil.cpu_count(logical=True)}T · {freq_str}"
        )
        self.ov_mem.update_data(
            vm.percent,
            f"{fmt_bytes(vm.used)} / {fmt_bytes(vm.total)}"
        )
        self.ov_disk.update_data(
            min(disk_mb, 100.0),
            f"{disk_mb:.2f} MB/s"
        )
        self.ov_net.update_data(
            min(recv_ks, 1000.0),
            f"↑ {sent_ks:.0f}  ↓ {recv_ks:.0f} KB/s"
        )
        self.proc_table.refresh(procs)

        # ── CPU detail ───────────────────────────────────────────────────
        for i, (bar, lbl) in enumerate(self._core_bars):
            if i < len(core_pcts):
                v = core_pcts[i]
                bar.set(v / 100)
                col = severity(v)
                bar.configure(progress_color=col)
                lbl.configure(text=f"{v:.0f}%", text_color=col)

        inf = self.cpu_info
        inf.set_section("Live")
        inf.set_row("Overall load", f"{cpu_pct:.1f}%", "cpu_tot")
        if freq:
            inf.set_row("Frequency", f"{freq.current:.0f} MHz", "cpu_freq")
        inf.set_row("Processes", str(len(psutil.pids())), "cpu_procs")
        inf.set_row("Threads", str(self._thread_count), "cpu_threads")
        inf.set_section("Processor")
        inf.set_row("Name", self._cpu_name[:56], "cpu_nm")
        inf.set_row("Architecture", platform.machine(), "cpu_arch")

        # ── Memory detail ────────────────────────────────────────────────
        self.ram_card.update_data(
            vm.percent,
            f"{fmt_bytes(vm.used)} / {fmt_bytes(vm.total)}"
        )
        self.swap_card.update_data(
            sw.percent,
            f"{fmt_bytes(sw.used)} / {fmt_bytes(sw.total)}"
        )
        mi = self.mem_info
        mi.set_section("Physical RAM")
        mi.set_row("Total", fmt_bytes(vm.total), "m_tot")
        mi.set_row("Used", fmt_bytes(vm.used), "m_used")
        mi.set_row("Available", fmt_bytes(vm.available), "m_avail")
        mi.set_row("Cached", fmt_bytes(getattr(vm, "cached", 0)), "m_cache")
        mi.set_row("Buffers", fmt_bytes(getattr(vm, "buffers", 0)), "m_buf")
        mi.set_section("Page File / Swap")
        mi.set_row("Total", fmt_bytes(sw.total), "sw_tot")
        mi.set_row("Used", fmt_bytes(sw.used), "sw_used")
        mi.set_row("Free", fmt_bytes(sw.free), "sw_free")

        # ── Disk I/O card ────────────────────────────────────────────────
        self.disk_io_card.update_data(
            min(disk_mb, 100.0),
            f"{disk_mb:.2f} MB/s total"
        )

        # Disk partitions — only rebuild when data refreshed
        if self._disk_tick == 0:
            for w in self.disk_parts_frame.winfo_children():
                w.destroy()
            for part in parts:
                self._build_disk_card(part)

        # ── Network detail ───────────────────────────────────────────────
        self.net_send_card.update_data(
            min(sent_ks, 1000.0),
            f"{sent_ks:.1f} KB/s"
        )
        self.net_recv_card.update_data(
            min(recv_ks, 1000.0),
            f"{recv_ks:.1f} KB/s"
        )
        ni = self.net_info
        ni.set_section("Session Totals")
        ni.set_row("Sent", fmt_bytes(net.bytes_sent), "n_sent")
        ni.set_row("Received", fmt_bytes(net.bytes_recv), "n_recv")
        ni.set_row("Packets ↑", f"{net.packets_sent:,}", "n_psent")
        ni.set_row("Packets ↓", f"{net.packets_recv:,}", "n_precv")
        if hasattr(net, "errin"):
            ni.set_section("Errors")
            ni.set_row("Errors in", str(net.errin), "n_ei")
            ni.set_row("Errors out", str(net.errout), "n_eo")
            ni.set_row("Drop in", str(net.dropin), "n_di")
            ni.set_row("Drop out", str(net.dropout), "n_do")

    def _build_disk_card(self, part: dict):
        card = ctk.CTkFrame(self.disk_parts_frame,
                            fg_color=BG_CARD, corner_radius=14,
                            border_width=1, border_color=BORDER)
        card.pack(fill="x", pady=5)

        hdr = ctk.CTkFrame(card, fg_color="transparent")
        hdr.pack(fill="x", padx=14, pady=(10, 0))

        ctk.CTkLabel(hdr,
                     text=f"⬤  {part['device']}",
                     font=FF(11, bold=True), text_color=AMBER).pack(side="left")
        ctk.CTkLabel(hdr,
                     text=f"({part['fstype']})  {part['mountpoint']}",
                     font=FF(9), text_color=TEXT_MID).pack(side="left", padx=8)
        ctk.CTkLabel(hdr,
                     text=f"{part['pct']:.1f}%",
                     font=FF(11, bold=True),
                     text_color=severity(part["pct"])).pack(side="right")

        bar = ctk.CTkProgressBar(card, height=6, corner_radius=3,
                                 fg_color=BORDER_H,
                                 progress_color=severity(part["pct"]))
        bar.set(part["pct"] / 100)
        bar.pack(fill="x", padx=14, pady=(6, 0))

        detail = ctk.CTkFrame(card, fg_color="transparent")
        detail.pack(fill="x", padx=14, pady=(4, 10))
        ctk.CTkLabel(detail,
                     text=f"{fmt_bytes(part['used'])} used",
                     font=FF(9, bold=True), text_color=TEXT_PRI).pack(side="left")
        ctk.CTkLabel(detail,
                     text=f"  of {fmt_bytes(part['total'])}",
                     font=FF(9), text_color=TEXT_MID).pack(side="left")
        ctk.CTkLabel(detail,
                     text=f"{fmt_bytes(part['free'])} free",
                     font=FF(9), text_color=EMERALD).pack(side="right")

    # ══════════════════════════════════════════════════════════════════════
    #  SHUTDOWN
    # ══════════════════════════════════════════════════════════════════════
    def on_close(self):
        self._running = False
        self.destroy()


# ═══════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app = HardwareMonApp()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()