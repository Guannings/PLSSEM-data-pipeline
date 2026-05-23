"""
Draw a TPB structural path diagram from PLS-SEM results.

Renders the 4-construct baseline model (AT, SN, PBC, BI) with the 5 structural
paths. Each path is labelled with its coefficient and significance; supported
paths (|t| > 1.96) are drawn solid, unsupported paths dashed.

The coefficients below are ILLUSTRATIVE PLACEHOLDERS so the script runs
stand-alone. Replace EXAMPLE_PATHS with the real values from the
`Path_Summary` tab of your run_plssem.R output.

Usage:
    python figures/draw_path_diagrams.py
"""

import os
import math
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

# --- ILLUSTRATIVE example results (replace with your Path_Summary) ----
# path -> (coefficient, significance label, supported?)
EXAMPLE_PATHS = {
    "AT->PBC": (0.50, "***", True),
    "SN->PBC": (0.30, "***", True),
    "AT->BI":  (0.12, "ns",  False),
    "SN->BI":  (0.22, "**",  True),
    "PBC->BI": (0.55, "***", True),
}

# --- layout -----------------------------------------------------------
NODES = {"AT": (1.0, 4.5), "SN": (1.0, 0.5), "PBC": (4.5, 2.5), "BI": (8.0, 2.5)}
NODE_W, NODE_H = 1.2, 0.8
PATHS_GEOM = {                       # path -> (start, end, curve_rad)
    "AT->PBC": ("AT", "PBC", 0.0),
    "SN->PBC": ("SN", "PBC", 0.0),
    "AT->BI":  ("AT", "BI", -0.18),
    "SN->BI":  ("SN", "BI",  0.18),
    "PBC->BI": ("PBC", "BI", 0.0),
}


def edge_point(start, end, w=NODE_W, h=NODE_H):
    """Where the line from `start` to `end` exits the `start` rectangle."""
    sx, sy = start
    ex, ey = end
    dx, dy = ex - sx, ey - sy
    dx = dx if abs(dx) > 1e-9 else 1e-9
    dy = dy if abs(dy) > 1e-9 else 1e-9
    t = min((w / 2) / abs(dx), (h / 2) / abs(dy))
    return sx + t * dx, sy + t * dy


def draw_node(ax, name, x, y):
    ax.add_patch(FancyBboxPatch(
        (x - NODE_W / 2, y - NODE_H / 2), NODE_W, NODE_H,
        boxstyle="round,pad=0.05,rounding_size=0.15",
        edgecolor="#1F4E78", facecolor="#DCEEFB", linewidth=2.0, zorder=3))
    ax.text(x, y, name, ha="center", va="center",
            fontsize=18, fontweight="bold", color="#1F4E78", zorder=4)


def draw_path(ax, start, end, coef, sig, supported, curve):
    sx, sy = edge_point(NODES[start], NODES[end])
    ex, ey = edge_point(NODES[end], NODES[start])
    color = "#1F4E78" if supported else "#999999"
    style = "-" if supported else (0, (4, 3))
    lw = 2.6 if supported else 1.4
    ax.add_patch(FancyArrowPatch(
        (sx, sy), (ex, ey), arrowstyle="-|>", mutation_scale=22,
        connectionstyle=f"arc3,rad={curve}",
        linewidth=lw, linestyle=style, color=color, zorder=2))

    # label at the midpoint, nudged perpendicular to the line
    mx, my = (sx + ex) / 2, (sy + ey) / 2
    dx, dy = ex - sx, ey - sy
    dist = math.hypot(dx, dy) or 1.0
    px, py = -dy / dist, dx / dist
    offset = 0.32 + abs(curve) * 1.2
    ax.text(mx + px * offset, my + py * offset,
            f"{coef:.2f}{'' if sig == 'ns' else sig}",
            ha="center", va="center", fontsize=13,
            color=color, fontweight="bold" if supported else "normal",
            bbox=dict(boxstyle="round,pad=0.2", facecolor="white",
                      edgecolor="none", alpha=0.95), zorder=5)


def draw_diagram(title, paths, out_path):
    fig, ax = plt.subplots(figsize=(10.5, 5.5))
    ax.set_xlim(0, 9.5)
    ax.set_ylim(-0.6, 5.5)
    ax.set_aspect("equal")
    ax.axis("off")

    for key, (start, end, curve) in PATHS_GEOM.items():
        coef, sig, supported = paths[key]
        draw_path(ax, start, end, coef, sig, supported, curve)
    for name, (x, y) in NODES.items():
        draw_node(ax, name, x, y)

    ax.set_title(title, fontsize=15, fontweight="bold", pad=10)
    n_sup = sum(1 for _, _, s in paths.values() if s)
    ax.text(4.75, -0.4,
            f"Solid = supported (|t| > 1.96): {n_sup}/5     "
            f"Dashed = not supported: {5 - n_sup}/5",
            ha="center", va="center", fontsize=10, color="#404040")

    fig.tight_layout()
    fig.savefig(out_path, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"saved: {out_path}")


def main():
    out_dir = "figures_output"
    os.makedirs(out_dir, exist_ok=True)
    draw_diagram("TPB baseline model (illustrative example values)",
                 EXAMPLE_PATHS, os.path.join(out_dir, "path_diagram_example.png"))
    print("Replace EXAMPLE_PATHS with your Path_Summary results to draw real "
          "diagrams.")


if __name__ == "__main__":
    main()
