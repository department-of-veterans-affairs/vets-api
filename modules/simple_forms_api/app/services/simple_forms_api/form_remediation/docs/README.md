# Form Remediation

This solution is designed to remediate form submissions older than two weeks, which have failed processing. It includes Ruby on Rails service objects, a Rake task, and a Sidekiq job, utilizing S3 for secure storage.

**Primary Use Case**: This remediation solution processes form submissions to generate an archive payload that includes:

1. Original form submission data, with remediation-specific files:
   - Hydrated submission data and attachments.
   - JSON metadata file with submission details.
   - CSV manifest for tracking submissions.
2. Zips and uploads the archive to an S3 bucket, with optional presigned URL access.
3. Supports single PDF uploads of original submissions.

---

## Table of Contents

- [Form Remediation](#form-remediation)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Settings](#settings)
    - [Configuration](#configuration)
  - [Usage](#usage)
    - [Batch Processing](#batch-processing)
      - [Rake Task Example](#rake-task-example)
      - [Batch Processing Job](#batch-processing-job)
    - [Individual Processing](#individual-processing)
  - [Extending Functionality](#extending-functionality)
    - [Overrideable Classes](#overrideable-classes)
    - [Directory and File Structure](#directory-and-file-structure)
      - [Structure Overview](#structure-overview)
    - [Naming Conventions](#naming-conventions)
  - [AWS S3 Bucket Setup](#aws-s3-bucket-setup)
    - [Requesting an S3 Bucket](#requesting-an-s3-bucket)
      - [Submit a PR](#submit-a-pr)
      - [Review Process](#review-process)
      - [Applying Changes](#applying-changes)
      - [Access and Credentials](#access-and-credentials)
    - [S3 Bucket Naming Convention](#s3-bucket-naming-convention)
    - [Future Infrastructure Requests](#future-infrastructure-requests)

---

## Getting Started

This solution is flexible, allowing extensive customization to suit various teams.

### Settings

Only the `region` and `bucket` settings for AWS S3 are required. The `vets-api` role accesses AWS credentials by default.

To use the provided uploader, ensure credentials are configured in `Settings` as follows:

```yml
bucket: <YOUR_TEAM_BUCKET>
region: <YOUR_TEAM_REGION>
```

If your settings differ, override the `s3_settings` method in your configuration class:

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewConfig < SimpleFormsApi::FormRemediation::Configuration::Base
  def s3_settings
    settings = Settings.<YOUR_TEAM>.<AWS_S3_SETTINGS>
    OpenStruct.new(bucket: settings.your_bucket_name, region: settings.your_region_name)
  end
end
```

For adding a `Settings` entry, refer to [Platform Documentation](https://depo-platform-documentation.scrollhelp.site/developer-docs/settings).

### Configuration

Set up a custom configuration by creating a subclass of `Base`, ensuring the `s3_settings` method is implemented:

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewConfig < SimpleFormsApi::FormRemediation::Configuration::Base
  def s3_settings
    Settings.<YOUR_TEAM>.<AWS_S3_SETTINGS>
  end
end
```

This solution uses the `:benefits_intake_uuid` identifier by default for querying `FormSubmission`, but this can be customized by setting `id_type` in your configuration.

---

## Usage

### Batch Processing

#### Rake Task Example

A Rake task for batch processing is available for reference, using `ArchiveBatchProcessingJob` to archive multiple form submissions and retrieve presigned URLs:

```sh
# Default type:
bundle exec rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456]

# Custom type:
bundle exec rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456,submission]
```

In `archive_forms_by_uuid`, `benefits_intake_uuids` specifies a collection of submission identifiers, and `type` defines the upload type (default is `remediation`). This task initializes a configuration object (`VffConfig`) and triggers the batch job, printing presigned URLs upon completion.

Note: **THIS RAKE TASK IS FOR REFERENCE ONLY!!** This rake task is specifically configured to interact with the Veteran Facing Forms team's S3 bucket, so please don't use it for your team.

#### Batch Processing Job

The `ArchiveBatchProcessingJob` handles batch processing of form submissions, iterating through each submission identifier to archive and upload it to S3. This job will initiate the archiving and uploading process directly through the `perform` method.

To initiate batch processing, use the following example:

```ruby
config = YourTeamsConfig.new
job = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.perform(ids: your_teams_ids, config:)
```

In this example:

- `perform` initiates the batch job, which processes each ID in `your_teams_ids` and uploads it based on the configuration provided.
- Presigned URLs for accessing uploaded files will be logged or otherwise handled as configured within the job. Ensure your configuration handles any post-upload actions required for your team.

Alternatively, you can create a custom job for specific team requirements:

```ruby
config = YourTeamsConfig.new
job = YourTeamsUniqueJob.perform(ids: your_teams_ids, config:)
```

In both cases, presigned URLs are not directly returned from `perform`. If your team needs to access presigned URLs programmatically after job completion, consider modifying the job’s output or handling the URLs as part of the logging or post-upload configuration.

### Individual Processing

To process a single ID, instantiate the `S3Client` directly:

```ruby
config = YourTeamsConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: your_teams_id)
client.upload
```

For PDF backups, specify `type: :submission` during initialization. This uploads the original form PDF and optionally returns a presigned URL:

```ruby
config = YourTeamsConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: your_teams_id, type: :submission)
client.upload
```

---

## Extending Functionality

Each component of this solution can be extended or customized to meet team requirements.

1. Review extensible components in the [Base Configuration](../../../../../../../lib/simple_forms_api/form_remediation/configuration/base.rb).
2. Create subclasses for required functionality.
3. Register the subclass in your configuration:

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewUploader < SimpleFormsApi::FormRemediation::Uploader
  def size_range
    (1.byte)...(50.megabytes)
  end
end
```

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewConfig < SimpleFormsApi::FormRemediation::Configuration::Base
  def s3_settings
    Settings.<YOUR_TEAM>.<AWS_S3_SETTINGS>
  end

  def uploader_class
    NewUploader
  end
end
```

```ruby
config = NewConfig.new
job = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.new
presigned_urls = job.perform(ids: benefits_intake_uuids, config:, type: :remediation)
```

### Overrideable Classes

- `submission_archive_class`: Customize archive generation.
- `s3_client`: Customize S3 interactions.
- `remediation_data_class`: Customize data processing for submissions.
- `uploader_class`: Customize file upload and S3 handling.
- `submission_type`: Define `FormSubmission` model queries.
- `attachment_type`: Define attachment model queries.

---

### Directory and File Structure

The S3 upload structure is organized to group archived files for each form submission. Files are stored based on a directory path that includes details like submission type and form-specific information, ensuring organized and traceable storage.

#### Structure Overview

1. **Base Directory (`parent_dir`)**: This is defined by your configuration and determines the top-level folder in the S3 bucket for all archived submissions.
2. **Upload Type Directory**: Submissions are stored in subdirectories based on the upload type (`:remediation` or `:submission`).
3. **Dated Directory**: Each submission includes a subdirectory named with a date-stamped identifier and the form number, such as `<MM.DD.YY>-Form<FormNumber>`, which is generated in the `dated_directory_name` method. This structure keeps submissions organized by date and form type.
4. **Files in Each Directory**:
   - **Archive File**: If the upload type is `:remediation`, the submission data and attachments are zipped into a single `.zip` file. This zip file contains:
     - **PDF of Submission**: The PDF representation of the original form submission.
     - **JSON Metadata**: A file with the original metadata from the submission.
     - **Attachments**: Any additional documents submitted with the form.
   - **PDF File**: For `:submission` type, only the original form submission is uploaded as a standalone `.pdf` file.

The following example illustrates the folder structure:

```bash
<parent_dir>/
├── remediation/
│   ├── 10.28.24-Form21-10210/
│   │   ├── 10.28.24_form_21-10210_vagov_abc123.zip  # Archive of PDF, metadata, and attachments
│   │   ├── 10.28.24_form_21-10210_vagov_bcd234.zip
│   │   └── manifest_10.28.24-Form21-10210.csv  # Manifest file for tracking
│   ├── 10.28.24-Form20-10207/
│   │   ├── 10.28.24_form_20-10207_vagov_ghi123.zip
│   │   ├── 10.28.24_form_20-10207_vagov_jkl456.zip
│   │   └── manifest_10.28.24-Form20-10207.csv
└── submission/
    ├── 10.28.24-Form21-4142/
    │   └── 10.28.24_form_21-4142_vagov_abc123.pdf  # Original form PDF only
    ├── 10.28.24-Form40-10007/
    │   └── 10.28.24_form_40-10007_vagov_abc123.pdf
```

### Naming Conventions

- **Dated Directory**: Follows `<MM.DD.YY>-Form<FormNumber>` format.
- **Zip Files**: Named `<MM.DD.YY>_form_<FormNumber>_vagov_<ID>.zip`.
- **PDF Files**: Named `<MM.DD.YY>_form_<FormNumber>_vagov_<ID>.pdf`.
- **Manifest Files**: Named `manifest_<MM.DD.YY>-Form<FormNumber>.csv`, which logs submission details and helps track archives uploaded to S3.

This structure and naming convention provides clear organization, helping locate specific submission archives by type, date, and form number.

---

## AWS S3 Bucket Setup

If your team does not have an S3 bucket, follow these steps.

### Requesting an S3 Bucket

#### Submit a PR

- **Recommended Approach**: Submit a configuration PR for new S3 bucket(s). Refer to [Sample PR #1](https://github.com/department-of-veterans-affairs/devops/pull/14735) and [Sample PR #2](https://github.com/department-of-veterans-affairs/devops/pull/14742) (these changes can be done in a single PR).
- Include staging and production configurations.
- Adhere to team naming conventions for the bucket(s).

#### Review Process

- Once the PR is submitted, request a review from the DevOps/Platform team.
- A team member should review the PR before DevOps approval.
- Request a **sanity check** for provisioning, security, and consistency.

#### Applying Changes

- After merging, DevOps will manually apply the changes in staging and production environments.
- Upon successful provisioning, DevOps will confirm bucket creation.

#### Access and Credentials

**Production/Staging**:

- `vets-api` automatically accesses S3 in production and staging environments through the **vets-api pod service account**.

**Local Development**:

- Use your own AWS credentials locally, either via environment variables or the AWS CLI.

**Testing Credentials**:

- Ensure the `vets-api` role can write to the S3 bucket in both environments. Test using the `vets-api` role and report any errors.

**Documentation**:

- Consult internal documentation on using `vets-api` role with AWS clients. For local development, ensure proper AWS credential setup.

### S3 Bucket Naming Convention

- **Staging**: `dsva-vagov-staging-[team-project-name]`
- **Production**: `dsva-vagov-prod-[team-project-name]`

### Future Infrastructure Requests

For future infrastructure needs, continue using PR requests in the DevOps repository. Seek Platform/DevOps assistance if unfamiliar with Terraform or infrastructure technologies, and verify permissions in staging and production environments.
