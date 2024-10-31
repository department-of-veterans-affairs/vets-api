# Form Remediation

This solution enables the remediation of failed form submissions over two weeks old within the Ruby on Rails `SimpleFormsApi` module. It consists of service objects that handle form archiving, metadata generation, and S3 interactions.

**Primary Use Case**: This remediation solution processes a form submission, generating an archive payload that includes:

1. Original form submission data, with remediation-specific files:
   - Hydrated submission data and attachments.
   - JSON metadata file with submission details.
   - CSV manifest for tracking submissions.
2. Zips the archive and uploads it to an S3 bucket.
3. Optionally returns a presigned URL for accessing the uploaded archive.

A backup option supports uploading individual form submissions as PDFs, with optional presigned URLs.

---

## Table of Contents

- [Getting Started](#getting-started)
  - [Settings](#settings)
  - [Configuration](#configuration)
- [Usage](#usage)
  - [Bulk Processing](#bulk-processing)
  - [Processing Individually](#processing-individually)
- [Extending Functionality](#extending-functionality)
- [AWS S3 Bucket Setup](#aws-s3-bucket-setup)

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

### Bulk Processing

The `ArchiveBatchProcessingJob` handles batch processing of form submissions. Initiate batch processing as shown:

```ruby
config = YourTeamsConfig.new
job = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.perform(ids: your_teams_ids, config:)
presigned_urls = job.upload(type: :remediation)
```

Alternatively, create a custom job:

```ruby
config = YourTeamsConfig.new
job = YourTeamsUniqueJob.perform(ids: your_teams_ids, config:)
presigned_urls = job.upload(type: :remediation)
```

### Processing Individually

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

Each step in this solution is extendable. Follow these steps:

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
- `submission_type`: Override `FormSubmission` model.
- `attachment_type`: Override attachment model.

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
