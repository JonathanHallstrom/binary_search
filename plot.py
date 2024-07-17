import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import pandas as pd
import numpy as np


def sizeof_fmt(x, pos):
    if x < 0:
        return ""
    for x_unit in ["bytes", "kB", "MB", "GB", "TB"]:
        if x < 1024:
            return "%3.0f %s" % (x, x_unit)
        x /= 1024


def time_fmt(x, pos):
    if x < 0:
        return ""
    for x_unit in ["ns", "us", "ms", "s"]:
        if x < 1000:
            return "%3.0f %s" % (x, x_unit)
        x /= 1000


def main(name):
    file = open(name + ".csv", "r")
    lines = file.readlines()

    data = []

    labels = lines[0].split(",")
    for i in range(1, len(lines)):
        data_points = [float(x) for x in lines[i].split(",")]
        data.append(data_points)

    file.close()

    df = pd.DataFrame(data, columns=labels)

    df_to_plot = df

    rolling_size = 50
    plt.figure(figsize=(14, 10))
    inf = float("inf")
    lo, hi = inf, -inf
    for label in labels[1:]:
        dashes = []
        if "lowerbound" in label.lower():
            dashes = [2, 2]
        if "upperbound" in label.lower():
            dashes = [8, 8]
        if "equalrange" in label.lower():
            dashes = [8, 2]
        smoothed_data = df_to_plot[label].rolling(7).median().rolling(rolling_size).mean()
        filter_nan = lambda a: a[~np.isnan(a)]
        lo = min(lo, min(filter_nan(smoothed_data)))
        hi = max(hi, max(filter_nan(smoothed_data)))

        plt.plot(
            df_to_plot["size"],
            smoothed_data,
            label=label,
            dashes=dashes,
        )

    plt.gca().set_yscale("log")

    if name == "relative":
        simple_formatter = lambda x, _: "%0.1f" % x
        plt.gca().yaxis.set_major_formatter(tkr.FuncFormatter(simple_formatter))
        plt.gca().yaxis.set_minor_formatter(tkr.FuncFormatter(simple_formatter))
    elif name == "absolute":
        plt.gca().yaxis.set_major_formatter(tkr.FuncFormatter(time_fmt))
    else:
        raise Exception("Unknown name: " + name)
    plt.gca().set_xscale("log")
    plt.gca().xaxis.set_major_formatter(tkr.FuncFormatter(sizeof_fmt))
    plt.gca().yaxis.set_major_locator(
        tkr.LogLocator(base=10.0, subs="auto", numticks=10)
    )
    plt.gca().yaxis.set_minor_locator(
        tkr.LogLocator(base=10.0, subs="auto", numticks=100)
    )
    plt.gca().grid(True, which="major", linestyle="--", linewidth=1)
    if name == "relative":
        lower_lim = 1
        print(lo, hi)
        while lower_lim > lo:
            lower_lim -= 0.1
        upper_lim = 1
        while upper_lim < hi:
            upper_lim += 1
        plt.gca().set_ylim(lower_lim, upper_lim)
    elif name == "absolute":
        lower_lim = 100
        print(lo, hi)
        while lower_lim > lo:
            lower_lim -= 1
        upper_lim = 0
        while upper_lim < hi:
            upper_lim += 100
        plt.gca().set_ylim(lower_lim, upper_lim)
    plt.xlabel("Size")
    plt.ylabel(
        "Nanoseconds"
        if name == "absolute"
        else "Time relative to old (lower is better)"
    )

    plt.title(f"Binary Search ({name} timings)")

    plt.legend()

    plt.savefig(name + ".png")
    plt.show()
    plt.close()


main("absolute")
main("relative")
