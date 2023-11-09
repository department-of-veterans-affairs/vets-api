# validate_yaml.py v1

import sys
import yaml
import json
import os
from jsonschema import validate, ValidationError
import argparse
from pathlib import Path
basepath = Path(__file__).parents[3]

# Class to help format the YAML output with prettier indents
class Dumper(yaml.Dumper):
    def increase_indent(self, flow=False, *args, **kwargs):
        return super().increase_indent(flow=flow, indentless=False)

# Set up arg parser and arguments
parser = argparse.ArgumentParser()
parser.add_argument("-F", "--filenames", nargs='*', default=[])
parser.add_argument("-s", "--schema-file")
args = parser.parse_args()

print("----------------------------------------------------------------------------")
# get schema string arg
schemaFileName = args.schema_file
# check that arg exists and raise exit error if missing
if schemaFileName is None or len(schemaFileName) < 1:
	print("Argument Error: Schema file path is required", file=sys.stderr)
	raise SystemExit(1)

# check that schema file actually exists and raise exit error if it does not
if not Path(schemaFileName).exists():
	print("The target directory for the schema file doesn't exist", file=sys.stderr)
	raise SystemExit(1)

# get schema array arg
filenames = args.filenames
# check that arg exists and raise exit error if it does not
if filenames is None:
	print("Argument Error: An array of file names is required", file=sys.stderr)
	raise SystemExit(1)

for filename in filenames:
  # check that yaml file actually exists and raise exit error if it does not
	if not Path(basepath.joinpath(filename)).exists():
		print("The target directory for the yaml file {} doesn't exist". format(filename), file=sys.stderr)
		raise SystemExit(1)

errors=0
# open schema file and dump to json  for validator
with open(schemaFileName, 'r') as schemaFile:
	s = json.load(schemaFile)

print("Validating Schemas for {} against {}\n\n".format(filenames, schemaFileName))

# validate each file against schema s. output and count any errors
for filename in args.filenames:
	with open(str(basepath.joinpath(filename)), 'r') as file:
		docs = yaml.safe_load_all(file)
		for doc in docs:
			try:
				validate(instance=doc, schema=s)
			except ValidationError as e:
				print("****************************** BEGIN VALIDATION ERROR ******************************\n", file=sys.stderr)
				print("Validation error in file {}".format(filename), file=sys.stderr)
				print(e.message, file=sys.stderr)
				print("Failed schema attribute: {}".format(e.validator), file=sys.stderr)
				print("\n++++++++++Failed YAML Doc+++++++++++\n", file=sys.stderr)
				print(yaml.dump(e.instance, Dumper=Dumper), file=sys.stderr)
				print("****************************** END VALIDATION ERROR ******************************\n", file=sys.stderr)
				errors += 1

print("\n\n")

# check for errors and exit appropriately
if errors > 0:
	print("Task failed with validation errors, check output for details", file=sys.stderr)
	print("----------------------------------------------------------------------------")
	raise SystemExit(1)
else:
	print("All files validated successfully")
	print("----------------------------------------------------------------------------")
	raise SystemExit(0)
