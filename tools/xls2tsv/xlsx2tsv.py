import argparse

import pandas as pd


def convert_xlsx_to_tsv(input_file: str,
                        out_dir: str,
                        sheet_selection: str):
    """
    Convert .xlsx file to .tsv format.
    When "sheet_names" is not specified, convert all sheets to single TSV files.

    Parameters
    ----------
    input_file: str
    Path to the input .xlsx file
    out_dir: str
    Path to the output dir where the TSV will be saved
    sheet_names: str
    Comma-separated list of sheet names to convert.

    Returns
    -------
    TSV file with the content of the .xlsx sheets
    """
    try:
        # Read the specified sheet or, if None, all the sheets
        data = pd.read_excel(input_file, sheet_name=sheet_selection)
        if sheet_selection is not None:
            # Create a single TSV files
            data.to_csv(f"{out_dir}/{sheet_selection}.tsv", sep='\t', index=False)
            print(f"Extracted sheet '{sheet_selection}' from {input_file}")
        else:
            for sheet_page, df in data.items():
                # Create several TSV files
                df.to_csv(f"{out_dir}/{sheet_page}.tsv", sep='\t', index=False)
                print(f"Extracted sheet '{sheet_page}' from {input_file}")
    except Exception as e:
        print(f"Failed to convert to TSV from {input_file}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Convert specific sheets from a single .xlsx file to .tsv format in the same directory.")
    parser.add_argument("--input-file", type=str, required=True, help="Path to the input .xlsx file.")
    parser.add_argument("--sheet_selection", type=str, required=False, default=None, help="Comma-separated list of sheet names to convert.")
    parser.add_argument('--out_dir', required=True, help="Output path where to create the .TSV files")
    args = parser.parse_args()

    # Call the conversion function with the provided arguments
    convert_xlsx_to_tsv(args.input_file, args.out_dir, args.sheet_selection)


if __name__ == "__main__":
    main()
