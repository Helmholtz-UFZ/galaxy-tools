import argparse
import pandas as pd
from py50.calculator import Calculator
from py50.plotcurve import PlotCurve
import matplotlib.pyplot as plt


parser = argparse.ArgumentParser(description="Calculate IC50 values, plot dose-response curves, and save results.")
parser.add_argument('file_path', type=str, help='Path to the CSV file containing the data.')
parser.add_argument('--plot_title', type=str, default='Default Plot Single Example (Positive)', help='Title for the plot.')
parser.add_argument('--drug_name', type=str, default='Drug 1', help='Name of the drug for labeling purposes.')
parser.add_argument('--output_plot', type=str, default='dose_response_curve.jpg', help='File name for saving the output plot as JPG.')
parser.add_argument('--output_ic50', type=str, default='ic50_values.txt', help='File name for saving the IC50 values as a text file.')
args = parser.parse_args()


df = pd.read_csv(args.file_path)

data = Calculator(df)
ic50 = data.calculate_ic50(name_col='compound', concentration_col='concentration', response_col='effect')

with open(args.output_ic50, 'w') as f:
    f.write(f"IC50 Value: {ic50}\n")

plot_data = PlotCurve(df)
fig, ax = plt.subplots()
fig = plot_data.single_curve_plot(ax=ax,
                            concentration_col='concentration',
                            response_col='effect',
                            plot_title=args.plot_title,
                            drug_name=args.drug_name,
                            xlabel='Concentration',
                            ylabel='Effect',
                            legend=True)

fig.savefig(args.output_plot, format='jpg', dpi=300)

