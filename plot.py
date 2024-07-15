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
        data.append([float(x) for x in lines[i].split(",")])

    file.close()

    df = pd.DataFrame(data, columns=labels)

    df_to_plot = df

    rolling_size = 100
    plt.figure(figsize=(14,10))
    for label in labels[1:]:
        plt.plot(
            df_to_plot["size"],
            df_to_plot[label].rolling(7).median().rolling(rolling_size).mean(),
            label=label,
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
    plt.gca().yaxis.set_major_locator(tkr.LogLocator(base=10.0, subs='auto', numticks=10))
    plt.gca().yaxis.set_minor_locator(tkr.LogLocator(base=10.0, subs='auto', numticks=100))
    plt.gca().grid(True, which='major', linestyle='--', linewidth=1)

    
    plt.xlabel("Size")
    plt.ylabel("Nanoseconds" if name == "absolute" else "Time relative to old (lower is better)")

    plt.title(f"Binary Search ({name} timings)")

    plt.legend()

    plt.savefig(name + ".png")
    plt.show()
    plt.close()


main("absolute")
main("relative")
