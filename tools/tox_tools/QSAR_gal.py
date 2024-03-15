import argparse

parser = argparse.ArgumentParser(description="Calculate log(1/EC) for a specified organism based on logDlipw.")

parser.add_argument('logDlipw', type=float, help="The logDlipw value")
parser.add_argument('organism', type=str, choices=['elegans', 'daphnia', 'zebrafish', 'xenopus', 'drosophila'],
                help="The organism for which to calculate log(1/EC)")
parser.add_argument('output_file', type=argparse.FileType('w'), help="Output file to write the results")

args = parser.parse_args()

def calculate_baseline(logDlipw, coefficient, intercept):
    return coefficient * logDlipw + intercept

organisms_data = {
"elegans": (0.81, 1.15),
"daphnia": (0.82, 1.48),
"zebrafish": (0.99, 0.78),
"xenopus": (0.6093, 2.117),
"drosophila": (0.8245, 0.5187)
}

coefficient, intercept = organisms_data[args.organism]
log_ec = calculate_baseline(args.logDlipw, coefficient, intercept)
output = f"Organism\tlog(1/EC)\n{args.organism}\t{log_ec}"
args.output_file.write(output)
args.output_file.close()


