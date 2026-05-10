import customtkinter as ctk
import psutil
import platform
import threading
import time
import os
import sys
from datetime import datetime

VERSION = "dev"

# ── Attempt GPU info (optional) ─────────────────────────────────────────────
try:
    import GPUtil
    GPU_AVAILABLE = True
except ImportError:
    GPU_AVAILABLE = False

# ── App configuration ────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

ACCENT   = "#0078D4"
ACCENT2  = "#60CDFF"
BG_BASE  = "#0A0A0F"
BG_CARD  = "#111118"
BG_SIDE  = "#0D0D14"
BORDER   = "#1E1E2E"
TEXT_PRI = "#F0F0F5"
TEXT_SEC = "#8888AA"
GREEN    = "#4DDB8A"
ORANGE   = "#FF8C42"
RED      = "#FF4D6D"

def severity_color(pct: float) -> str:
    if pct < 60:   return GREEN
    if pct < 85:   return ORANGE
    return RED

def get_cpu_name() -> str:
    """Return a proper CPU marketing name, e.g. 'Intel Core i7-12700K @ 3.60GHz'.
    Tries the Windows registry first, falls back to platform.processor(), then
    a psutil-derived string so it always returns something useful."""
    # 1) Windows registry — most reliable source of the marketing name
    try:
        import winreg
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        )
        name, _ = winreg.QueryValueEx(key, "ProcessorNameString")
        winreg.CloseKey(key)
        name = " ".join(name.split())   # collapse whitespace
        if name:
            return name
    except Exception:
        pass
    # 2) platform.processor() — usually readable on non-Windows too
    try:
        p = platform.processor().strip()
        if p and p.lower() not in ("", "unknown"):
            return p
    except Exception:
        pass
    # 3) Last resort: architecture + core count
    cores_p = psutil.cpu_count(logical=False) or "?"
    cores_l = psutil.cpu_count(logical=True)  or "?"
    return f"{platform.machine()} CPU  {cores_p}C / {cores_l}T"

# ── Tiny history ring-buffer ─────────────────────────────────────────────────
class RingBuffer:
    def __init__(self, size=60):
        self.size = size
        self.data = [0.0] * size

    def push(self, v: float):
        self.data.pop(0)
        self.data.append(float(v))

    def last(self) -> float:
        return self.data[-1]


# ── Mini sparkline canvas ────────────────────────────────────────────────────
class Sparkline(ctk.CTkCanvas):
    def __init__(self, master, buf: RingBuffer, color=ACCENT2, **kw):
        super().__init__(master, bg=BG_CARD, highlightthickness=0, **kw)
        self.buf   = buf
        self.color = color
        self.bind("<Configure>", lambda _: self._draw())

    def _draw(self):
        self.delete("all")
        W, H = self.winfo_width(), self.winfo_height()
        if W < 2 or H < 2:
            return
        data = self.buf.data
        n    = len(data)
        hi   = max(max(data), 1)
        pts  = []
        for i, v in enumerate(data):
            x = i * W / (n - 1)
            y = H - (v / hi) * (H - 4) - 2
            pts.extend([x, y])
        if len(pts) >= 4:
            fill_pts = [pts[0], H] + pts + [pts[-2], H]
            self.create_polygon(fill_pts, fill=self._hex_alpha(self.color, 0.15),
                                outline="", smooth=True)
            self.create_line(pts, fill=self.color, width=1.5, smooth=True)

    @staticmethod
    def _hex_alpha(hex_color: str, alpha: float) -> str:
        h = hex_color.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        br, bg_, bb = 17, 17, 24
        nr = int(br + (r - br) * alpha)
        ng = int(bg_ + (g - bg_) * alpha)
        nb = int(bb + (b - bb) * alpha)
        return f"#{nr:02x}{ng:02x}{nb:02x}"

    def pulse_glow(self):
        """Flash a brief glow overlay on the sparkline when value spikes."""
        self._glow_alpha = 0.55
        self._animate_glow()

    def _animate_glow(self):
        if not hasattr(self, "_glow_alpha") or self._glow_alpha <= 0:
            self.delete("glow")
            return
        W, H = self.winfo_width(), self.winfo_height()
        self.delete("glow")
        # draw a semi-transparent rectangle as a glow wash
        col = self._hex_alpha(self.color, self._glow_alpha)
        self.create_rectangle(0, 0, W, H, fill=col, outline="", tags="glow")
        self._draw()   # redraw line on top
        self._glow_alpha -= 0.07
        self.after(30, self._animate_glow)


# ── Animated number label ────────────────────────────────────────────────────
class AnimatedLabel(ctk.CTkLabel):
    """A CTkLabel that smoothly animates numeric text changes."""

    def __init__(self, master, fmt: str = "{:.1f}", suffix: str = "", **kw):
        super().__init__(master, **kw)
        self._fmt     = fmt
        self._suffix  = suffix
        self._current = 0.0
        self._target  = 0.0
        self._after_id = None

    def set_value(self, target: float, color: str | None = None):
        self._target = target
        if color:
            self.configure(text_color=color)
        self._animate()

    def _animate(self):
        if self._after_id:
            self.after_cancel(self._after_id)
        diff = self._target - self._current
        if abs(diff) < 0.15:
            self._current = self._target
            self._render()
            return
        self._current += diff * 0.22
        self._render()
        self._after_id = self.after(16, self._animate)

    def _render(self):
        try:
            self.configure(text=self._fmt.format(self._current) + self._suffix)
        except Exception:
            pass


# ── Animated arc gauge ───────────────────────────────────────────────────────
class ArcGauge(ctk.CTkCanvas):
    def __init__(self, master, size=80, **kw):
        super().__init__(master, width=size, height=size,
                         bg=BG_CARD, highlightthickness=0, **kw)
        self._size    = size
        self._value   = 0.0
        self._target  = 0.0
        self._after_id = None
        self._draw(0.0, GREEN)

    def set(self, pct: float):
        self._target = max(0.0, min(100.0, pct))
        self._animate()

    def _animate(self):
        if self._after_id:
            self.after_cancel(self._after_id)
        diff = self._target - self._value
        if abs(diff) < 0.5:
            self._value = self._target
            self._draw(self._value, severity_color(self._value))
            return
        self._value += diff * 0.18
        self._draw(self._value, severity_color(self._value))
        self._after_id = self.after(16, self._animate)

    def _draw(self, pct: float, color: str):
        self.delete("all")
        s = self._size
        pad = 6
        self.create_arc(pad, pad, s - pad, s - pad,
                        start=220, extent=-260,
                        style="arc", outline=BORDER, width=5)
        extent = -260 * (pct / 100)
        if abs(extent) > 0.5:
            self.create_arc(pad, pad, s - pad, s - pad,
                            start=220, extent=extent,
                            style="arc", outline=color, width=5)
        self.create_text(s // 2, s // 2 - 3,
                         text=f"{pct:.0f}%",
                         fill=TEXT_PRI, font=("Segoe UI Variable", 13, "bold"))


# ── Individual metric card ───────────────────────────────────────────────────
class MetricCard(ctk.CTkFrame):
    def __init__(self, master, title: str, icon: str, buf: RingBuffer,
                 color=ACCENT2, unit="%", **kw):
        super().__init__(master, fg_color=BG_CARD, corner_radius=12,
                         border_width=1, border_color=BORDER, **kw)
        self.buf   = buf
        self.unit  = unit
        self.color = color
        self._prev_val = 0.0

        hdr = ctk.CTkFrame(self, fg_color="transparent")
        hdr.pack(fill="x", padx=14, pady=(12, 0))
        ctk.CTkLabel(hdr, text=icon, font=("Segoe UI Emoji", 18),
                     text_color=color).pack(side="left")
        ctk.CTkLabel(hdr, text=title, font=("Segoe UI Variable", 12, "bold"),
                     text_color=TEXT_PRI).pack(side="left", padx=8)

        val_row = ctk.CTkFrame(self, fg_color="transparent")
        val_row.pack(fill="x", padx=14, pady=(6, 0))

        self.gauge = ArcGauge(val_row, size=72)
        self.gauge.pack(side="left")

        info_col = ctk.CTkFrame(val_row, fg_color="transparent")
        info_col.pack(side="left", padx=10, fill="both", expand=True)

        # Use AnimatedLabel for the main value so it counts up smoothly
        fmt = "{:.1f}" if unit != " KB/s" and unit != " MB/s" else "{:.0f}"
        self.val_label = AnimatedLabel(
            info_col, fmt=fmt, suffix=unit,
            font=("Segoe UI Variable", 22, "bold"),
            text=f"0{unit}", text_color=TEXT_PRI
        )
        self.val_label.pack(anchor="w")
        self.sub_label = ctk.CTkLabel(info_col, text="",
                                      font=("Segoe UI Variable", 10),
                                      text_color=TEXT_SEC)
        self.sub_label.pack(anchor="w")

        self.spark = Sparkline(self, buf=buf, color=color, height=36)
        self.spark.pack(fill="x", padx=14, pady=(8, 12))

        # Fade-in animation on first render
        self._fade_alpha = 0.0
        self.after(10, self._fade_in)

    def _fade_in(self):
        """Simulate a fade-in by briefly highlighting the border."""
        steps = [ACCENT, ACCENT2, BORDER]
        def step(i=0):
            if i < len(steps):
                try:
                    self.configure(border_color=steps[i])
                except Exception:
                    pass
                self.after(120, lambda: step(i + 1))
        step()

    def update_data(self, pct: float, sub: str = ""):
        color = severity_color(pct) if self.unit == "%" else TEXT_PRI
        self.val_label.set_value(pct, color=color)
        self.sub_label.configure(text=sub)
        self.gauge.set(pct)
        self.spark._draw()
        # Trigger glow when value jumps by more than 15 points
        if abs(pct - self._prev_val) > 15:
            self.spark.pulse_glow()
        self._prev_val = pct


# ── Detail info panel (right side) ──────────────────────────────────────────
class InfoPanel(ctk.CTkScrollableFrame):
    def __init__(self, master, **kw):
        super().__init__(master, fg_color="transparent",
                         scrollbar_button_color=BORDER,
                         scrollbar_button_hover_color=ACCENT, **kw)
        self._rows: dict[str, ctk.CTkLabel] = {}
        # FIX: track which section headers have been created to avoid duplicates
        self._sections: set[str] = set()

    def set_section(self, title: str):
        # FIX: only create section header widgets once
        if title in self._sections:
            return
        self._sections.add(title)
        ctk.CTkLabel(self, text=title,
                     font=("Segoe UI Variable", 11, "bold"),
                     text_color=ACCENT2).pack(anchor="w", padx=4, pady=(10, 2))
        sep = ctk.CTkFrame(self, fg_color=BORDER, height=1)
        sep.pack(fill="x", padx=4, pady=(0, 4))

    def set_row(self, key: str, value: str, key_id: str = ""):
        rid = key_id or key
        if rid in self._rows:
            self._rows[rid].configure(text=value)
            return
        row = ctk.CTkFrame(self, fg_color="transparent")
        row.pack(fill="x", padx=4, pady=1)
        ctk.CTkLabel(row, text=key,
                     font=("Segoe UI Variable", 10),
                     text_color=TEXT_SEC, width=130, anchor="w").pack(side="left")
        lbl = ctk.CTkLabel(row, text=value,
                           font=("Segoe UI Variable", 10, "bold"),
                           text_color=TEXT_PRI, anchor="w")
        lbl.pack(side="left")
        self._rows[rid] = lbl


# ── Process list ─────────────────────────────────────────────────────────────
class ProcessTable(ctk.CTkFrame):
    def __init__(self, master, **kw):
        super().__init__(master, fg_color=BG_CARD, corner_radius=12,
                         border_width=1, border_color=BORDER, **kw)
        hdr = ctk.CTkFrame(self, fg_color="transparent")
        hdr.pack(fill="x", padx=14, pady=(12, 4))
        ctk.CTkLabel(hdr, text="⚙  Top Processes",
                     font=("Segoe UI Variable", 12, "bold"),
                     text_color=TEXT_PRI).pack(side="left")

        cols_frame = ctk.CTkFrame(self, fg_color=BORDER, corner_radius=6)
        cols_frame.pack(fill="x", padx=14, pady=(0, 2))
        for col, w in [("Process", 180), ("PID", 55), ("CPU %", 60), ("RAM MB", 70)]:
            ctk.CTkLabel(cols_frame, text=col, width=w,
                         font=("Segoe UI Variable", 9, "bold"),
                         text_color=TEXT_SEC, anchor="w").pack(side="left", padx=4, pady=3)

        self.rows_frame = ctk.CTkScrollableFrame(
            self, fg_color="transparent", height=160,
            scrollbar_button_color=BORDER,
            scrollbar_button_hover_color=ACCENT
        )
        self.rows_frame.pack(fill="x", padx=14, pady=(0, 10))

    def refresh(self, procs):
        for w in self.rows_frame.winfo_children():
            w.destroy()
        for i, p in enumerate(procs[:12]):
            row = ctk.CTkFrame(self.rows_frame,
                               fg_color="#16161F" if i % 2 == 0 else "transparent",
                               corner_radius=4)
            row.pack(fill="x", pady=1)
            name = (p["name"][:22] + "…") if len(p["name"]) > 23 else p["name"]
            vals = [name, str(p["pid"]),
                    f"{p['cpu']:.1f}", f"{p['mem']:.0f}"]
            widths = [180, 55, 60, 70]
            colors = [TEXT_PRI, TEXT_SEC, severity_color(p["cpu"]), TEXT_PRI]
            for val, w, c in zip(vals, widths, colors):
                ctk.CTkLabel(row, text=val, width=w,
                             font=("Segoe UI Variable", 9),
                             text_color=c, anchor="w").pack(side="left", padx=4, pady=2)


# ── Sidebar nav button ───────────────────────────────────────────────────────
class NavButton(ctk.CTkButton):
    def __init__(self, master, text, icon, command, **kw):
        super().__init__(master,
                         text=f"  {icon}  {text}",
                         font=("Segoe UI Variable", 12),
                         fg_color="transparent",
                         hover_color="#1A1A2A",
                         text_color=TEXT_SEC,
                         anchor="w",
                         height=38,
                         corner_radius=8,
                         command=command, **kw)

    def set_active(self, active: bool):
        if active:
            self.configure(fg_color="#0D1F33", text_color=ACCENT2,
                           border_color=ACCENT, border_width=1)
        else:
            self.configure(fg_color="transparent", text_color=TEXT_SEC,
                           border_width=0)


# ═══════════════════════════════════════════════════════════════════════════
#  MAIN APPLICATION
# ═══════════════════════════════════════════════════════════════════════════
class HardwareMonApp(ctk.CTk):
    PAGES = ["Overview", "CPU", "Memory", "Disk", "Network", "System"]

    def __init__(self):
        super().__init__()
        self.title("HardwareMon")
        self.geometry("1100x700")
        self.minsize(900, 580)
        self.configure(fg_color=BG_BASE)

        # ring buffers
        self.cpu_buf  = RingBuffer(60)
        self.mem_buf  = RingBuffer(60)
        self.disk_buf = RingBuffer(60)
        self.net_buf  = RingBuffer(60)
        # FIX: dedicated buffers for cards that had anonymous RingBuffer() instances
        self.swap_buf     = RingBuffer(60)
        self.net_send_buf = RingBuffer(60)
        self.net_recv_buf = RingBuffer(60)

        self._current_page = "Overview"
        self._nav_buttons: dict[str, NavButton] = {}
        self._pages: dict[str, ctk.CTkFrame] = {}
        self._cpu_name = get_cpu_name()   # cached — only needs reading once
        self._prev_net      = psutil.net_io_counters()
        self._prev_net_time = time.time()
        # FIX: track previous disk I/O counters to compute a rate, not cumulative total
        self._prev_disk     = psutil.disk_io_counters()
        self._prev_disk_time = time.time()

        # FIX: cache for disk partitions — only refresh every 10 ticks
        self._disk_parts_cache: list = []
        self._disk_parts_tick  = 0

        # FIX: cache thread count — expensive to compute every tick
        self._thread_count   = 0
        self._thread_tick    = 0

        self._build_layout()
        self._build_sidebar()
        self._build_pages()
        self._show_page("Overview")

        self._running = True
        self._update_thread = threading.Thread(target=self._data_loop, daemon=True)
        self._update_thread.start()

    # ── Layout skeleton ──────────────────────────────────────────────────────
    def _build_layout(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(1, weight=1)

        topbar = ctk.CTkFrame(self, fg_color=BG_CARD, corner_radius=0,
                              border_width=0, height=48)
        topbar.grid(row=0, column=0, columnspan=2, sticky="ew")
        topbar.grid_propagate(False)
        self.topbar_ref = topbar

        ctk.CTkLabel(topbar, text="⬡  HardwareMon",
                     font=("Segoe UI Variable", 14, "bold"),
                     text_color=ACCENT2).pack(side="left", padx=20)

        self.time_label = ctk.CTkLabel(topbar, text="",
                                       font=("Segoe UI Variable", 10),
                                       text_color=TEXT_SEC)
        self.time_label.pack(side="right", padx=20)

        self.status_dot = ctk.CTkLabel(topbar, text="● LIVE",
                                       font=("Segoe UI Variable", 10, "bold"),
                                       text_color=GREEN)
        self.status_dot.pack(side="right", padx=8)

        self.sidebar = ctk.CTkFrame(self, fg_color=BG_SIDE, corner_radius=0,
                                    border_width=0, width=188)
        self.sidebar.grid(row=1, column=0, sticky="nsew")
        self.sidebar.grid_propagate(False)

        self.content = ctk.CTkFrame(self, fg_color="transparent", corner_radius=0)
        self.content.grid(row=1, column=1, sticky="nsew")
        self.content.grid_columnconfigure(0, weight=1)
        self.content.grid_rowconfigure(0, weight=1)

        # Start the pulsing LIVE dot
        self._live_pulse_state = 0
        self.after(800, self._pulse_live_dot)

    # ── Sidebar ──────────────────────────────────────────────────────────────
    def _build_sidebar(self):
        ctk.CTkLabel(self.sidebar, text="NAVIGATION",
                     font=("Segoe UI Variable", 9),
                     text_color=TEXT_SEC).pack(anchor="w", padx=16, pady=(18, 4))

        icons = {"Overview": "🏠", "CPU": "🖥️", "Memory": "💾",
                 "Disk": "💿", "Network": "🌐", "System": "ℹ️"}

        for page in self.PAGES:
            btn = NavButton(self.sidebar, page, icons[page],
                            command=lambda p=page: self._show_page(p))
            btn.pack(fill="x", padx=10, pady=2)
            self._nav_buttons[page] = btn

        ctk.CTkLabel(
            self.sidebar,
            text=f"HardwareMon\n{VERSION} Windows",
            font=("Segoe UI Variable", 9),
            text_color=TEXT_SEC
        ).pack(side="bottom", pady=16)

    def _pulse_live_dot(self):
        """Alternate the LIVE dot between bright green and dim to simulate a pulse."""
        colors = [GREEN, "#1A6640", GREEN, "#1A6640", GREEN]
        def step(i=0):
            if i < len(colors):
                try:
                    self.status_dot.configure(text_color=colors[i])
                except Exception:
                    pass
                self.after(180, lambda: step(i + 1))
            else:
                self.after(2200, self._pulse_live_dot)
        step()

    def _shimmer_bar(self, bar: ctk.CTkProgressBar):
        """Sweep a progress bar from 0→1→0 as a startup eye-candy animation."""
        val = [0.0]
        going_up = [True]
        def tick():
            if going_up[0]:
                val[0] = min(val[0] + 0.07, 1.0)
                if val[0] >= 1.0:
                    going_up[0] = False
            else:
                val[0] = max(val[0] - 0.07, 0.0)
                if val[0] <= 0.0:
                    return   # done
            try:
                bar.set(val[0])
                bar.configure(progress_color=ACCENT2)
            except Exception:
                return
            self.after(18, tick)
        tick()

    # ── Page builder ─────────────────────────────────────────────────────────
    def _build_pages(self):
        for page in self.PAGES:
            frame = ctk.CTkFrame(self.content, fg_color="transparent",
                                 corner_radius=0)
            frame.grid(row=0, column=0, sticky="nsew")
            self._pages[page] = frame

        self._build_overview()
        self._build_cpu_page()
        self._build_memory_page()
        self._build_disk_page()
        self._build_network_page()
        self._build_system_page()

    def _show_page(self, name: str):
        self._current_page = name
        for n, btn in self._nav_buttons.items():
            btn.set_active(n == name)
        self._pages[name].tkraise()
        # Brief border-flash on the content area to signal page switch
        self._flash_content()

    def _flash_content(self):
        """Flash the topbar accent briefly when switching pages."""
        seq = [ACCENT2, ACCENT, BG_CARD]
        def step(i=0):
            if i < len(seq):
                try:
                    self.topbar_ref.configure(fg_color=seq[i])
                except Exception:
                    pass
                self.after(60, lambda: step(i + 1))
        step()

    # ── Overview page ────────────────────────────────────────────────────────
    def _build_overview(self):
        p = self._pages["Overview"]
        p.grid_columnconfigure((0, 1, 2, 3), weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="Overview",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0, columnspan=4,
                                               sticky="w", padx=20, pady=(16, 8))

        self.ov_cpu  = MetricCard(p, "CPU Usage", "🖥️", self.cpu_buf,  color=ACCENT2)
        self.ov_mem  = MetricCard(p, "Memory",    "💾", self.mem_buf,  color="#A78BFA")
        self.ov_disk = MetricCard(p, "Disk I/O",  "💿", self.disk_buf, color=ORANGE,
                                  unit=" MB/s")
        self.ov_net  = MetricCard(p, "Network",   "🌐", self.net_buf,  color=GREEN,
                                  unit=" KB/s")

        for i, card in enumerate([self.ov_cpu, self.ov_mem,
                                   self.ov_disk, self.ov_net]):
            card.grid(row=1, column=i, padx=(12 if i == 0 else 6, 6 if i < 3 else 12),
                      pady=(0, 12), sticky="nsew")

        self.proc_table = ProcessTable(p)
        self.proc_table.grid(row=2, column=0, columnspan=4,
                             padx=12, pady=(0, 12), sticky="ew")

    # ── CPU detail page ──────────────────────────────────────────────────────
    def _build_cpu_page(self):
        p = self._pages["CPU"]
        p.grid_columnconfigure(0, weight=2)
        p.grid_columnconfigure(1, weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="CPU Details",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0, columnspan=2,
                                               sticky="w", padx=20, pady=(16, 8))

        self.cpu_cores_frame = ctk.CTkFrame(p, fg_color=BG_CARD,
                                            corner_radius=12,
                                            border_width=1, border_color=BORDER)
        self.cpu_cores_frame.grid(row=1, column=0, padx=(12, 6),
                                  pady=(0, 12), sticky="nsew")

        ctk.CTkLabel(self.cpu_cores_frame, text="Per-Core Usage",
                     font=("Segoe UI Variable", 11, "bold"),
                     text_color=TEXT_PRI).pack(anchor="w", padx=14, pady=(10, 4))

        self.core_bars_frame = ctk.CTkScrollableFrame(
            self.cpu_cores_frame, fg_color="transparent",
            scrollbar_button_color=BORDER,
            scrollbar_button_hover_color=ACCENT
        )
        self.core_bars_frame.pack(fill="both", expand=True, padx=8, pady=(0, 8))
        self._core_bars: list = []

        n = psutil.cpu_count(logical=True)
        cols = 2 if n <= 8 else 4
        for i in range(n):
            r, c = divmod(i, cols)
            cell = ctk.CTkFrame(self.core_bars_frame, fg_color="transparent")
            cell.grid(row=r, column=c, padx=6, pady=3, sticky="ew")
            self.core_bars_frame.grid_columnconfigure(c, weight=1)
            ctk.CTkLabel(cell, text=f"C{i}", width=24,
                         font=("Segoe UI Variable", 9),
                         text_color=TEXT_SEC).pack(side="left")
            bar = ctk.CTkProgressBar(cell, height=8, corner_radius=4,
                                     fg_color=BORDER, progress_color=ACCENT2)
            bar.set(0)
            bar.pack(side="left", fill="x", expand=True, padx=4)
            pct_lbl = ctk.CTkLabel(cell, text="0%", width=32,
                                   font=("Segoe UI Variable", 9),
                                   text_color=TEXT_SEC)
            pct_lbl.pack(side="left")
            self._core_bars.append((bar, pct_lbl))
            # Startup shimmer: sweep each bar to 100% then back to 0 staggered
            self.after(300 + i * 40, lambda b=bar: self._shimmer_bar(b))

        self.cpu_info = InfoPanel(p)
        self.cpu_info.grid(row=1, column=1, padx=(0, 12),
                           pady=(0, 12), sticky="nsew")

    # ── Memory detail page ───────────────────────────────────────────────────
    def _build_memory_page(self):
        p = self._pages["Memory"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_columnconfigure(1, weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="Memory",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0, columnspan=2,
                                               sticky="w", padx=20, pady=(16, 8))

        # FIX: use dedicated swap_buf so the sparkline has real history
        self.ram_card  = MetricCard(p, "RAM",       "💾", self.mem_buf,  color="#A78BFA")
        self.swap_card = MetricCard(p, "Page File",  "📄", self.swap_buf, color="#F472B6", unit="%")
        self.ram_card.grid( row=1, column=0, padx=(12, 6), pady=(0, 12), sticky="nsew")
        self.swap_card.grid(row=1, column=1, padx=(6, 12), pady=(0, 12), sticky="nsew")
        self.mem_info = InfoPanel(p)
        self.mem_info.grid(row=2, column=0, columnspan=2,
                           padx=12, pady=(0, 12), sticky="ew")

    # ── Disk detail page ─────────────────────────────────────────────────────
    def _build_disk_page(self):
        p = self._pages["Disk"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="Disk",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0,
                                               sticky="w", padx=20, pady=(16, 8))

        self.disk_partitions_frame = ctk.CTkScrollableFrame(
            p, fg_color="transparent",
            scrollbar_button_color=BORDER,
            scrollbar_button_hover_color=ACCENT
        )
        self.disk_partitions_frame.grid(row=1, column=0, padx=12,
                                        pady=(0, 12), sticky="nsew")

    # ── Network detail page ──────────────────────────────────────────────────
    def _build_network_page(self):
        p = self._pages["Network"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_columnconfigure(1, weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="Network",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0, columnspan=2,
                                               sticky="w", padx=20, pady=(16, 8))

        # FIX: use dedicated buffers so sparklines accumulate real history
        self.net_send_card = MetricCard(p, "Upload",   "⬆️",
                                        self.net_send_buf, color=ORANGE, unit=" KB/s")
        self.net_recv_card = MetricCard(p, "Download", "⬇️",
                                        self.net_recv_buf, color=GREEN,  unit=" KB/s")
        self.net_send_card.grid(row=1, column=0, padx=(12, 6),
                                pady=(0, 12), sticky="nsew")
        self.net_recv_card.grid(row=1, column=1, padx=(6, 12),
                                pady=(0, 12), sticky="nsew")

        self.net_info = InfoPanel(p)
        self.net_info.grid(row=2, column=0, columnspan=2,
                           padx=12, pady=(0, 12), sticky="ew")

    # ── System info page ─────────────────────────────────────────────────────
    def _build_system_page(self):
        p = self._pages["System"]
        p.grid_columnconfigure(0, weight=1)
        p.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(p, text="System Information",
                     font=("Segoe UI Variable", 20, "bold"),
                     text_color=TEXT_PRI).grid(row=0, column=0,
                                               sticky="w", padx=20, pady=(16, 8))

        self.sys_info = InfoPanel(p)
        self.sys_info.grid(row=1, column=0, padx=12,
                           pady=(0, 12), sticky="nsew")

        self._populate_system_info()

    def _populate_system_info(self):
        inf = self.sys_info
        inf.set_section("Operating System")
        inf.set_row("OS",       platform.system() + " " + platform.release())
        inf.set_row("Version",  platform.version()[:60])
        inf.set_row("Machine",  platform.machine())
        inf.set_row("Node",     platform.node())

        inf.set_section("Processor")
        inf.set_row("CPU",            get_cpu_name()[:64])
        inf.set_row("Physical cores", str(psutil.cpu_count(logical=False)))
        inf.set_row("Logical cores",  str(psutil.cpu_count(logical=True)))
        try:
            freq = psutil.cpu_freq()
            if freq:
                inf.set_row("Max freq", f"{freq.max:.0f} MHz")
        except Exception:
            pass

        inf.set_section("Memory")
        vm = psutil.virtual_memory()
        inf.set_row("Total RAM",  self._fmt_bytes(vm.total))
        sw = psutil.swap_memory()
        inf.set_row("Page file",  self._fmt_bytes(sw.total))

        if GPU_AVAILABLE:
            try:
                gpus = GPUtil.getGPUs()
                if gpus:
                    inf.set_section("GPU")
                    for i, gpu in enumerate(gpus):
                        inf.set_row(f"GPU {i}", gpu.name)
                        inf.set_row("VRAM",    f"{gpu.memoryTotal:.0f} MB")
            except Exception:
                pass

        inf.set_section("Python")
        inf.set_row("Version", sys.version[:40])

    # ── Data loop (background thread) ────────────────────────────────────────
    def _data_loop(self):
        # Prime cpu_percent so first reading isn't 0.0
        psutil.cpu_percent(interval=None)
        psutil.cpu_percent(percpu=True)
        while self._running:
            try:
                self._collect_and_update()
            except Exception:
                pass
            time.sleep(1)

    def _collect_and_update(self):
        # ── CPU ──────────────────────────────────────────────────────────────
        cpu_pct   = psutil.cpu_percent(interval=None)
        core_pcts = psutil.cpu_percent(percpu=True)
        self.cpu_buf.push(cpu_pct)

        # ── Memory ───────────────────────────────────────────────────────────
        vm       = psutil.virtual_memory()
        mem_pct  = vm.percent
        sw       = psutil.swap_memory()
        self.mem_buf.push(mem_pct)
        # FIX: push swap into its own buffer
        self.swap_buf.push(sw.percent)

        # ── Disk I/O (rate, not cumulative) ──────────────────────────────────
        # FIX: compute MB/s delta between ticks instead of pushing raw totals
        disk_mb_s = 0.0
        try:
            now_d  = time.time()
            dio    = psutil.disk_io_counters()
            dt_d   = max(now_d - self._prev_disk_time, 0.001)
            delta  = (
                (dio.read_bytes  - self._prev_disk.read_bytes) +
                (dio.write_bytes - self._prev_disk.write_bytes)
            )
            disk_mb_s = max(delta / dt_d / 1024 / 1024, 0.0)
            self._prev_disk      = dio
            self._prev_disk_time = now_d
        except Exception:
            pass
        self.disk_buf.push(disk_mb_s)

        # ── Network ──────────────────────────────────────────────────────────
        now  = time.time()
        net  = psutil.net_io_counters()
        dt   = max(now - self._prev_net_time, 0.001)
        sent = max((net.bytes_sent - self._prev_net.bytes_sent) / dt / 1024, 0.0)
        recv = max((net.bytes_recv - self._prev_net.bytes_recv) / dt / 1024, 0.0)
        self._prev_net      = net
        self._prev_net_time = now
        self.net_buf.push(recv)
        # FIX: push into dedicated send/recv buffers
        self.net_send_buf.push(sent)
        self.net_recv_buf.push(recv)

        # ── Processes (lightweight) ───────────────────────────────────────────
        # FIX: avoid cpu_percent per-process on every tick (too slow); collect
        # only what we need and guard all attribute access
        procs = []
        for proc in psutil.process_iter(["pid", "name", "cpu_percent",
                                          "memory_info"]):
            try:
                info = proc.info
                procs.append({
                    "pid":  info["pid"],
                    "name": info["name"] or "—",
                    "cpu":  info["cpu_percent"] or 0.0,
                    "mem":  (info["memory_info"].rss / 1024 / 1024
                             if info["memory_info"] else 0.0)
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        procs.sort(key=lambda x: x["cpu"], reverse=True)

        # ── Disk partitions (cached — only refresh every 10 ticks) ───────────
        # FIX: rebuilding partition widgets every second causes visible stutter
        self._disk_parts_tick += 1
        if self._disk_parts_tick >= 10 or not self._disk_parts_cache:
            parts = []
            for part in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    parts.append({"device":     part.device,
                                  "mountpoint": part.mountpoint,
                                  "fstype":     part.fstype,
                                  "total":      usage.total,
                                  "used":       usage.used,
                                  "pct":        usage.percent})
                except Exception:
                    pass
            self._disk_parts_cache = parts
            self._disk_parts_tick  = 0
        parts = self._disk_parts_cache

        # ── CPU freq ─────────────────────────────────────────────────────────
        try:
            freq = psutil.cpu_freq()
        except Exception:
            freq = None

        # ── Thread count (cached every 5 ticks — iterating all threads is slow)
        self._thread_tick += 1
        if self._thread_tick >= 5:
            try:
                self._thread_count = sum(
                    p.num_threads()
                    for p in psutil.process_iter()
                )
            except Exception:
                pass
            self._thread_tick = 0

        self.after(0, self._update_ui,
                   cpu_pct, core_pcts, mem_pct, vm, sw,
                   sent, recv, net, procs, parts, freq,
                   disk_mb_s)
        self.after(0, self._update_clock)

    def _update_clock(self):
        self.time_label.configure(
            text=datetime.now().strftime("%A, %d %B %Y  %H:%M:%S")
        )

    def _update_ui(self, cpu_pct, core_pcts, mem_pct, vm, sw,
                   sent, recv, net, procs, parts, freq, disk_mb_s):

        # ── Overview ─────────────────────────────────────────────────────────
        self.ov_cpu.update_data(cpu_pct,
            f"{psutil.cpu_count(logical=True)} cores · {freq.current:.0f} MHz" if freq else "")
        self.ov_mem.update_data(mem_pct,
            f"{self._fmt_bytes(vm.used)} / {self._fmt_bytes(vm.total)}")
        # FIX: show actual MB/s rate; clamp gauge to 100 for display only
        self.ov_disk.update_data(min(disk_mb_s, 100.0),
            f"{disk_mb_s:.2f} MB/s")
        self.ov_net.update_data(min(recv, 1000),
            f"↑ {sent:.0f}  ↓ {recv:.0f} KB/s")

        self.proc_table.refresh(procs)

        # ── CPU detail ───────────────────────────────────────────────────────
        for i, (bar, lbl) in enumerate(self._core_bars):
            if i < len(core_pcts):
                v = core_pcts[i] / 100
                bar.set(v)
                bar.configure(progress_color=severity_color(core_pcts[i]))
                lbl.configure(text=f"{core_pcts[i]:.0f}%",
                              text_color=severity_color(core_pcts[i]))

        inf = self.cpu_info
        inf.set_section("Current")
        inf.set_row("Overall",   f"{cpu_pct:.1f}%",         "cpu_overall")
        if freq:
            inf.set_row("Frequency", f"{freq.current:.0f} MHz", "cpu_freq")
        inf.set_row("Processes",  str(len(psutil.pids())),   "cpu_procs")
        inf.set_row("Threads",    str(self._thread_count),   "cpu_threads")
        inf.set_section("Processor")
        inf.set_row("Name", self._cpu_name[:52], "cpu_name")

        # ── Memory detail ────────────────────────────────────────────────────
        self.ram_card.update_data(mem_pct,
            f"{self._fmt_bytes(vm.used)} / {self._fmt_bytes(vm.total)}")
        self.swap_card.update_data(sw.percent,
            f"{self._fmt_bytes(sw.used)} / {self._fmt_bytes(sw.total)}")

        mi = self.mem_info
        mi.set_section("RAM")
        mi.set_row("Total",     self._fmt_bytes(vm.total),     "m_total")
        mi.set_row("Used",      self._fmt_bytes(vm.used),      "m_used")
        mi.set_row("Available", self._fmt_bytes(vm.available), "m_avail")
        mi.set_row("Buffers",   self._fmt_bytes(getattr(vm, "buffers", 0)), "m_buf")
        mi.set_section("Page File")
        mi.set_row("Total", self._fmt_bytes(sw.total), "sw_total")
        mi.set_row("Used",  self._fmt_bytes(sw.used),  "sw_used")

        # ── Disk detail (only rebuild widgets when partition data refreshed) ──
        # FIX: only destroy/recreate partition widgets when data actually changed
        if self._disk_parts_tick == 0:
            for w in self.disk_partitions_frame.winfo_children():
                w.destroy()
            for part in parts:
                card = ctk.CTkFrame(self.disk_partitions_frame, fg_color=BG_CARD,
                                    corner_radius=10, border_width=1, border_color=BORDER)
                card.pack(fill="x", pady=4)
                hdr = ctk.CTkFrame(card, fg_color="transparent")
                hdr.pack(fill="x", padx=12, pady=(8, 0))
                ctk.CTkLabel(hdr, text=f"💿  {part['device']}  ({part['fstype']})",
                             font=("Segoe UI Variable", 11, "bold"),
                             text_color=TEXT_PRI).pack(side="left")
                ctk.CTkLabel(hdr, text=f"{part['pct']:.1f}%",
                             font=("Segoe UI Variable", 11, "bold"),
                             text_color=severity_color(part['pct'])).pack(side="right")
                bar = ctk.CTkProgressBar(card, height=6, corner_radius=3,
                                         fg_color=BORDER,
                                         progress_color=severity_color(part['pct']))
                bar.set(part['pct'] / 100)
                bar.pack(fill="x", padx=12, pady=4)
                ctk.CTkLabel(card,
                             text=f"{self._fmt_bytes(part['used'])} used of {self._fmt_bytes(part['total'])}",
                             font=("Segoe UI Variable", 9), text_color=TEXT_SEC
                             ).pack(anchor="w", padx=12, pady=(0, 8))

        # ── Network detail ────────────────────────────────────────────────────
        self.net_send_card.update_data(min(sent, 1000), f"{sent:.1f} KB/s")
        self.net_recv_card.update_data(min(recv, 1000), f"{recv:.1f} KB/s")

        ni = self.net_info
        ni.set_section("Totals")
        ni.set_row("Sent",      self._fmt_bytes(net.bytes_sent), "n_sent")
        ni.set_row("Received",  self._fmt_bytes(net.bytes_recv), "n_recv")
        ni.set_row("Packets ↑", str(net.packets_sent),           "n_psent")
        ni.set_row("Packets ↓", str(net.packets_recv),           "n_precv")

    # ── Helpers ──────────────────────────────────────────────────────────────
    @staticmethod
    def _fmt_bytes(b: int) -> str:
        for unit in ("B", "KB", "MB", "GB", "TB"):
            if b < 1024:
                return f"{b:.1f} {unit}"
            b /= 1024
        return f"{b:.1f} PB"

    def on_close(self):
        self._running = False
        self.destroy()


# ── Entry point ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app = HardwareMonApp()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()