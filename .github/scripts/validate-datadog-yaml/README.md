# Validate YAML Script
The script in this file is used to validate Datadog Service Catalog YAML files against the Datadog Service JSON Schema. 

The script itself will validate any list of YAML files against a schema file provided.

## Usage
Install python version 3.10+
Install requirements
```shell
$ pip install -r requirements.txt
```
<br>
Call `validate_yaml.py` from the command line the following manner

```shell
$ python validate_yaml.py [-s] <schemaFilePath> [-F] <filePathsToValidate>
```

```
$ python validate_yaml.py -s -s path/to/schema.json -F [path/to/file1.yml path.to/file2.yaml]
```

## Datadog Schema Information
The [schema](https://github.com/DataDog/schema/blob/main/service-catalog/v2/schema.json) for the current usage is from the [Datadog API for Service Definition API](https://docs.datadoghq.com/api/latest/service-definition/)

