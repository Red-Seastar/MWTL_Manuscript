from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.ticker import FormatStrFormatter
import numpy as np


mpl.rcParams["font.family"] = "STIXGeneral"
mpl.rcParams["mathtext.fontset"] = "stix"

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent

FILES = [
    SCRIPT_DIR / "Coil 1.txt",
    SCRIPT_DIR / "Coil 2.txt",
    SCRIPT_DIR / "Coil 3.txt",
]
OUTPUTS = [
    ROOT_DIR / "field1.png",
    ROOT_DIR / "field2.png",
    ROOT_DIR / "field3.png",
]

ROI = (-70.0, 70.0, -70.0, 70.0)
N_LEVELS = 10
FIXED_TICK_NUM = 5
DPI = 400


def read_cst_signed_hz(path: Path):
    data = np.loadtxt(path, skiprows=2)
    x = data[:, 0]
    y = data[:, 1]
    hz_re = data[:, 7]
    hz_im = data[:, 8]
    signed_mag = np.sign(hz_re) * np.hypot(hz_re, hz_im)

    x_grid = np.unique(x)
    y_grid = np.unique(y)
    z_grid = np.full((len(y_grid), len(x_grid)), np.nan)

    x_index = {value: index for index, value in enumerate(x_grid)}
    y_index = {value: index for index, value in enumerate(y_grid)}
    for x_value, y_value, z_value in zip(x, y, signed_mag):
        z_grid[y_index[y_value], x_index[x_value]] = z_value

    x_mask = (x_grid >= ROI[0]) & (x_grid <= ROI[1])
    y_mask = (y_grid >= ROI[2]) & (y_grid <= ROI[3])
    return x_grid[x_mask], y_grid[y_mask], z_grid[np.ix_(y_mask, x_mask)]


def red_white_blue():
    return LinearSegmentedColormap.from_list(
        "red_white_blue",
        [(0.0, "#0000ff"), (0.5, "#ffffff"), (1.0, "#ff0000")],
        N=256,
    )


def exact_ticks(low: float, high: float, count: int):
    ticks = np.linspace(low, high, count)
    if float(low).is_integer() and float(high).is_integer():
        ticks[1:-1] = np.round(ticks[1:-1])
    return ticks


def plot_field(x_grid, y_grid, z_grid, output_path: Path, clim: float, show_colorbar: bool):
    fig_height = 5.1 if show_colorbar else 4.6
    fig, ax = plt.subplots(figsize=(5.8, fig_height), dpi=100)
    if show_colorbar:
        fig.subplots_adjust(top=0.78)

    levels = np.linspace(-clim, clim, N_LEVELS + 1)
    filled = ax.contourf(x_grid, y_grid, z_grid, levels=levels, cmap=red_white_blue())
    ax.contour(x_grid, y_grid, z_grid, levels=[0], colors="black", linewidths=1.1)

    ax.set_aspect("equal", adjustable="box")
    ax.set_xlim(ROI[0], ROI[1])
    ax.set_ylim(ROI[2], ROI[3])
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_xlabel("")
    ax.set_ylabel("")
    ax.tick_params(width=1.5, length=0)
    for spine in ax.spines.values():
        spine.set_visible(False)

    if show_colorbar:
        fig.canvas.draw()
        ax_pos = ax.get_position()
        cbar_width = ax_pos.width * 0.9
        cbar_left = ax_pos.x0 + (ax_pos.width - cbar_width) / 2
        cbar_ax = fig.add_axes([cbar_left, 0.86, cbar_width, 0.045])
        colorbar = fig.colorbar(
            filled,
            cax=cbar_ax,
            orientation="horizontal",
        )
        colorbar.set_ticks([-50, -25, 0, 25, 50])
        colorbar.ax.xaxis.set_major_formatter(FormatStrFormatter("%.0f"))
        colorbar.ax.xaxis.set_ticks_position("top")
        colorbar.ax.xaxis.set_label_position("top")
        colorbar.ax.set_xlabel(r"$H_z$ (A/m)", fontsize=22, labelpad=7)
        colorbar.ax.tick_params(labelsize=20, width=1.5, direction="out", pad=3)

    fig.savefig(output_path, dpi=DPI, bbox_inches="tight")
    plt.close(fig)


def main():
    fields = [read_cst_signed_hz(path) for path in FILES]
    shared_clim = max(float(np.nanmax(np.abs(z_grid))) for _, _, z_grid in fields)

    for index, ((x_grid, y_grid, z_grid), output_path) in enumerate(zip(fields, OUTPUTS)):
        plot_field(x_grid, y_grid, z_grid, output_path, shared_clim, show_colorbar=index == 1)
        print(f"Saved: {output_path}")


if __name__ == "__main__":
    main()
