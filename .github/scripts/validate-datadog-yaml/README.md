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

## Notes on `validate-datadog-changes.yml` and `validate-datadog-changes-skip.yml`
There are two workflows that have the same job named `validate_files`. These jobs have the same name because GitHub [required actions for PRs ignore filters and branches.](https://docs.github.com/en/actions/using-workflows/required-workflows#prerequisites) In order to overcome this and still have a check, we either need to [make the job run on conditionals to skip](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks#handling-skipped-but-required-checks), or run a job with the same name on opposite filters.  

Because this job is using a git diff against master, we cannot use the GH suggested method. the `github` context does not provide the change set, nor can we run a diff against `master`. That means we do not have the information we need when a conditional is called at the top of the job to be certain. 

By using two workflows with opposite paths filters, we can run a job with the same name every PR and branch protection will see that job name and validate on whichever workflow runs for the change set. 
