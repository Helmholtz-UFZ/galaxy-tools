import pandas as pd
import re
import argparse
import re

parser = argparse.ArgumentParser(description='Calculate baseline toxicity for different aquatic species')
parser.add_argument('--function', type=str, choices=['calculate_baseline', 'apply_linear_functions'],
                    help='Function to execute')
parser.add_argument('--csv_input', type=argparse.FileType('r'), help='Path to the input csv file')
parser.add_argument('--functions_csv', type=argparse.FileType('r'), default=None,
                    help='Path to the csv file containing functions (only for apply_linear_functions)')
parser.add_argument('--output', type=argparse.FileType('w'), help='Path for the output csv file')
args = parser.parse_args()

if args.function == 'calculate_baseline':
        df = pd.read_csv(args.csv_input)
        df.iloc[:, 0] = df.iloc[:, 0].astype(int)
        df['Caenorhabditis elegans [mol/L]'] = 10**(-(0.81 * df.iloc[:, 0] + 1.15))
        df['Daphia magna [mol/L]'] = 10**(-(0.82 * df.iloc[:, 0] + 1.48))
        df['Danio rerio [mol/L]'] = 10**(-(0.99 * df.iloc[:, 0] + 0.78))
        df['Generic Human Cells [mol/L]'] = 0.026 / (10**df.iloc[:, 0]) * (1 + 10**(0.7*df.iloc[:, 0]+0.34) * 3 * 0.001 + 10**(3) * 0.07 * 0.001)
        df.to_csv(args.output, index=False)

elif args.function == 'apply_linear_functions':
        df = pd.read_csv(args.csv_input)
        functions_df = pd.read_csv(args.functions_csv)


        def parse_and_apply_equation(equation, x_values):
            # Extract 'a' and 'b' from the equation  (assuming the format 'ax+b' or 'ax-b')
            pattern = re.compile(r'([+-]?\d*\.?\d*)x([+-]\d+)?')
            match = pattern.search(equation)
            a = float(match.group(1)) if match.group(1) not in ('', '+', '-') else 1.0
            b = float(match.group(2)) if match.group(2) else 0
            return a * x_values + b


        for i, row in functions_df.iterrows():
            func = row['function']
            df[f'result_{i}'] = parse_and_apply_equation(func, df['logD'])
        df.to_csv(args.output, index=False)
