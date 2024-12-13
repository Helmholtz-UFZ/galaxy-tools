import pandas as pd
import argparse


def convert_xlsx_to_tsv(input_file, sheet_name, output):
    try:
        # Read the specified sheet and convert them to tsv
        df = pd.read_excel(input_file, sheet_name=sheet_name)
        output_filename = f"{sheet_name}.tsv"
        df.to_csv(output, sep='\t', index=False)
        print(f"Converted sheet '{sheet_name}' from {input_file} to {output_filename}")

    except Exception as e:
        print(f"Failed to convert sheet '{sheet_name}' from {input_file}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Convert specific sheets from a single .xlsx file to .tsv format in the same directory.")
    parser.add_argument("--input-file", type=str, required=True, help="Path to the input .xlsx file.")
    parser.add_argument("--sheet-names", type=str, required=True, help="Comma-separated list of sheet names to convert.")
    parser.add_argument("--output", type=str, default="extracted_sheet.tsv", required=False, help="Suffix for the tsv file")
    args = parser.parse_args()

    # Convert sheet names from str to list
    sheet_names = args.sheet_names

    # Call the conversion function with the provided arguments
    convert_xlsx_to_tsv(args.input_file, sheet_names, args.output)


if __name__ == "__main__":
    main()
