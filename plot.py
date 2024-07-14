import matplotlib.pyplot as plt
import matplotlib.ticker as tkr  
import pandas as pd

def sizeof_fmt(x, pos):
    if x<0:
        return ""
    for x_unit in ['bytes', 'kB', 'MB', 'GB', 'TB']:
        if x < 1024:
            return "%3.0f %s" % (x, x_unit)
        x /= 1024

def main(name):
    file = open(name + ".csv", "r")
    lines = file.readlines()

    data = []

    for i in range(0, len(lines), 1):
        line = lines[i]
        line = line.split(",")

        size = int(line[0])

        old_time = float(line[1])
        branchless_time = float(line[2])
        prefetch_time = float(line[3])
        careful_prefetch_time = float(line[4])

        data.append([size, old_time, branchless_time, prefetch_time, careful_prefetch_time])

    file.close()

    df = pd.DataFrame(data, columns=["size", "old", "branchless", "prefetch", "careful"])

    df_to_plot = df

    rolling_size = 100
    plt.plot(df_to_plot["size"], df_to_plot["old"].rolling(7).median().rolling(rolling_size).mean(), label="old")
    plt.plot(df_to_plot["size"], df_to_plot["branchless"].rolling(7).median().rolling(rolling_size).mean(), label="branchless")
    plt.plot(df_to_plot["size"], df_to_plot["prefetch"].rolling(7).median().rolling(rolling_size).mean(), label="prefetch")
    plt.plot(df_to_plot["size"], df_to_plot["careful"].rolling(7).median().rolling(rolling_size).mean(), label="careful")

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
