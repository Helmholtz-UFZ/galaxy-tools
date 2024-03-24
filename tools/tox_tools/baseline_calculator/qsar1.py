import pandas as pd
import argparse

parser = argparse.ArgumentParser(description='Calculate baseline toxicity for different aquatic species')
parser.add_argument('--function', type=str, choices=['calculate_baseline', 'apply_linear_functions'],
                    help='Function to execute')
parser.add_argument('--csv_input', type=argparse.FileType('r'), help='Path to the input CSV file')
parser.add_argument('--functions_csv', type=argparse.FileType('r'), default=None,
                    help='Path to the CSV file containing functions (only for apply_linear_functions)')
parser.add_argument('--output', type=argparse.FileType('w'), help='Path for the output CSV file')
args = parser.parse_args()

if args.function == 'calculate_baseline':
    if args.csv_input is not None and args.output is not None:
        df = pd.read_csv(args.csv_input)
        df.iloc[:, 0] = df.iloc[:, 0].astype(int)
        df['C.elegans'] = 0.81 * df.iloc[:, 0] + 1.15
        df['D.magna'] = 0.82 * df.iloc[:, 0] + 1.48
        df['D.rerio'] = 0.99 * df.iloc[:, 0] + 0.78
        df['X.laevis'] = 0.6093 * df.iloc[:, 0] + 2.117
        df['D.melanogaster'] = 0.8245 * df.iloc[:, 0] + 0.5187
        df.to_csv(args.output, index=False)

elif args.function == 'apply_linear_functions':
    if args.csv_input is not None and args.functions_csv is not None and args.output is not None:
        df = pd.read_csv(args.csv_input)
        functions_df = pd.read_csv(args.functions_csv)


        def parse_and_apply_equation(equation, x_values):
            # Extract 'a' and 'b' from the equation string (assuming the format 'ax+b' or 'ax-b')
            parts = equation.replace('x', '').replace('+', ' ').replace('-', ' -').split()
            a = float(parts[0])
            b = float(parts[1]) if len(parts) > 1 else 0
            return a * x_values + b


        for i, row in functions_df.iterrows():
            func = row['function']
            df[f'result_{i}'] = parse_and_apply_equation(func, df['logD'])
        df.to_csv(args.output, index=False)
