import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import pandas as pd


def sizeof_fmt(x, pos):
    if x < 0:
        return ""
    for x_unit in ["bytes", "kB", "MB", "GB", "TB"]:
        if x < 1024:
            return "%3.0f %s" % (x, x_unit)
        x /= 1024


def main(name):
    file = open(name + ".csv", "r")
    lines = file.readlines()

    data = []

    labels = lines[0].split(",")
    for i in range(1, len(lines)):
        data.append([float(x) for x in lines[i].split(",")])

    file.close()

    df = pd.DataFrame(data, columns=labels)

    df_to_plot = df

    rolling_size = 100
    for label in labels[1:]:
        plt.plot(
            df_to_plot["size"],
            df_to_plot[label].rolling(7).median().rolling(rolling_size).mean(),
            label=label,
        )

    if name != "relative":
        plt.gca().set_yscale("log")
    plt.gca().set_xscale("log")
    plt.gca().xaxis.set_major_formatter(tkr.FuncFormatter(sizeof_fmt))

    plt.xlabel("Size")
    plt.ylabel("Nanoseconds" if name == "absolute" else "Time relative to old")

    plt.title(f"Binary Search ({name} timings)")

    plt.legend()

    plt.savefig(name + ".png")
    plt.show()
    plt.close()


main("absolute")
main("relative")
