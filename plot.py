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

def main():
    file = open("data.txt", "r")
    lines = file.readlines()

    data = []

    for i in range(0, len(lines), 1):
        line = lines[i]
        line = line.split(",")

        size = int(line[0])

        new_time = int(line[1])
        old_time = int(line[2])

        data.append([size, new_time, old_time])

    file.close()

    df = pd.DataFrame(data, columns=["size", "new", "old"])

    df_to_plot = df

    plt.plot(df_to_plot["size"], df_to_plot["new"].rolling(25).mean(), label="new")
    plt.plot(df_to_plot["size"], df_to_plot["old"].rolling(25).mean(), label="old")

    plt.gca().set_yscale("log")
    plt.gca().set_xscale("log")
    plt.gca().xaxis.set_major_formatter(tkr.FuncFormatter(sizeof_fmt))

    plt.xlabel("Size")
    plt.ylabel("Nanoseconds")

    plt.title("Binary Search")

    plt.legend()

    plt.savefig("graph.png")
    plt.show()

main()
