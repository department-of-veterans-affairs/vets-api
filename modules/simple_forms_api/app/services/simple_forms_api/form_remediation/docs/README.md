# Form Remediation

This solution is designed to remediate form submissions which have failed submission and are over two weeks old. It is composed of several Ruby on Rails service objects which interact with each other.

The primary use-case for this solution is for form remediation. This process consists of the following:

1. Accept a form submission identifier.
1. Generate an archive payload consisting of the original form submission data as well as remediation specific documentation:
    1. Hydrate the original form submission
    1. Hydrate any original attachments that were a part of this submission
    1. Generate a JSON file with the original metadata from the submission
    1. Generate a manifest file to be used in the remediation process
1. Upload the generated archive as a .zip file onto the configured S3 bucket
1. Optionally return a presigned URL for accessing this file

This solution also provides a means for storing and retrieving a single .pdf copy of the originally submitted form.

The following image depicts how this solution is architected:

![Error Remediation Architecture](./error_remediation_architecture.png)

---

## Table of Contents

- [Getting Started](#getting-started)
  - [Settings](#settings)
  - [Configuration](#configuration)
- [Usage](#usage)
- [Extending Functionality](#extending-functionality)
- [AWS S3 Bucket Setup](#aws-s3-bucket-setup)

---

## Getting Started

This service has been built in such a way that almost all aspects of the workflow can be configured or extended, depending upon your team's needs.

### Settings

The AWS S3 `region` and `bucket` are the only AWS credentials which need to be present. The S3 upload process uses a relatively new approach of using `vets-api`'s account role to access AWS. DevOps logic exists which defaults the AWS account key and secret to that role's credentials.

In order to use the provided [Veteran Facing Forms uploader](../../../../../../../app/uploaders/simple_forms_api/form_remediation/uploader.rb), the AWS credentials will need to be included in the following format:

```yml
  bucket: <YOUR_TEAM_BUCKET>
  region: <YOUR_TEAM_REGION>
```

If your team's credentials are in a different format, the s3_settings method can be overridden to account for this:

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

To create a `Settings` entry, follow the [documentation provided by Platform](https://depo-platform-documentation.scrollhelp.site/developer-docs/settings).

### Configuration

Your team can configure the service as it currently exists with minimal code additions.

1. Create a new configuration file, inheriting from the base configuration class. Ensure that at the very least, the `s3_settings` method has been implemented.

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewConfig < SimpleFormsApi::FormRemediation::Configuration::Base
  def s3_settings
    Settings.<YOUR_TEAM>.<AWS_S3_SETTINGS>
  end
end
```

It's also worth noting that this solution by default queries FormSubmission's by the `:benefits_intake_uuid` identifier by default, but that can be overridden within the configuration by setting the `id_type` attribute.

---

## Usage

The Veteran Facing Forms team currently calls the bulk processing job utilizing [a rake task](../../../../../../simple_forms_api/lib/tasks/archive_forms_by_uuid.rake). Your team may choose to call it a different way but this is how we handle it.

### Bulk Processing

For convenience, we've created a job which processes multiple form submissions at once by iterating through a collection of UUIDs. This batch processing can be handled in multiple ways.

The service can be called with our existing job:

```ruby
config = YourTeamsConfig.new
job = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.perform(ids: your_teams_ids, config:)
presigned_urls = job.upload(type: :remediation)
```

Or your own custom job:

```ruby
config = YourTeamsConfig.new
job = YourTeamsUniqueJob.perform(ids: your_teams_ids, config:)
presigned_urls = job.upload(type: :remediation)
```

### Processing Individually

If your team isn't concerned with bulk processing, the S3 client itself handles processing an individual id for remediation out of the box:

```ruby
config = YourTeamsConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: your_teams_id)
client.upload
```

The client also supports backing up individual form submissions in their original PDF format. This can be accomplished by changing the `type` to `:submission` during client initialization. This option will hydrate the form submission PDF and upload it to the configured S3 bucket and optionally return a presigned URL which links to the PDF itself. The subsequent remediation documentation is not created given this option.

```ruby
config = YourTeamsConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: your_teams_id, type: :submission)
client.upload
```

---

## Extending Functionality

In addition to configuration of existing logic, if your team requires something other than what this service provides, each step of the process can be substituted or skipped with basic inheritance.

1. Take note of what can be extended and how it's used in the [base configuration](../../../../../../../lib/simple_forms_api/form_remediation/configuration/base.rb).
1. Create a new class, optionally extending the existing one.
1. Update your team's configuration to include the newly created class. These classes include:
    1. `submission_archive_class` - Override to inject your team's own submission archive
    1. `s3_client` - Override to inject your team's own s3 client
    1. `remediation_data_class` - Override to inject your team's own submission data builder service
    1. `uploader_class` - Override to inject your team's own file uploader
    1. `submission_type` - The FormSubmission model to query against
    1. `attachment_type` - The attachment model to query for form submission attachments
1. Pass the new configiration in when calling the service.

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

---

## AWS S3 Bucket Setup

If your team does not have their own dedicated AWS S3 bucket, the following steps will need to be taken.

### S3 Bucket Request Process

#### **Submit PR**

- **Preferred Approach by Platform DevOps**: Create a new configuration PR to add the necessary S3 bucket(s) using these PRs as guidance (these changes can be done in a single PR): [Sample PR #1](https://github.com/department-of-veterans-affairs/devops/pull/14735), [Sample PR #2](https://github.com/department-of-veterans-affairs/devops/pull/14742)
  - Include the appropriate configuration for both staging and production environments.
  - Ensure you follow your team's naming convention when creating the bucket(s).

#### **Review Process**

- Once the PR is submitted, request a review from the DevOps/Platform team.
  - A teammate should review the PR first before requesting a review from DevOps.
- Ask for a **sanity check** to ensure the bucket is provisioned correctly, securely, and consistently with existing infrastructure.

#### **Apply Changes**

- After the PR is merged, the DevOps team will apply the Terraform changes to provision the bucket(s) in the appropriate environment (staging/production).
  - At the time of writing this document, this process is manual for DevOps and will need to be asked for explicitly once the PR has been merged.
- Once the bucket(s) are successfully created, the DevOps or platform team will provide confirmation.

#### **Access and Credentials**

**Production/Staging Environments**:

- The `vets-api` service will automatically have access to the S3 bucket in production and staging environments through the **vets-api pod's service account**.
- No explicit AWS Access Key or Secret Key is needed in these environments, as the credentials will be [fetched automatically](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#initialize-instance_method) by the pod service account.

**Local Development/Non-Production Environments**:

- For local testing or other non-production environments, you **will need to pass your own AWS credentials** (e.g., via environment variables or AWS CLI) when working with S3.

**Testing Credentials**:

- Ensure that the `vets-api` role can write to the S3 bucket in both staging and production. You should test your S3 client with the `vets-api` role and report any errors.
- If you're using an AWS client (e.g., via the AWS SDK), it should automatically use the `vets-api` role in the target environment.

**Documentation**:

- Internal documentation on using the `vets-api` role with AWS clients should be consulted for further guidance. For local development, ensure AWS credentials are properly set up.

### S3 Bucket Naming Convention

- **For Staging**: `dsva-vagov-staging-[team-project-name]`
- **For Production**: `dsva-vagov-prod-[team-project-name]`

### Guidelines for Future Infrastructure Requests

- Teams should continue to request infrastructure changes via PRs to the DevOps repository.
- If you're unfamiliar with Terraform or any other infrastructure specific technologies, request assistance from the Platform or DevOps team to ensure the infrastructure is provisioned correctly.
- Ensure proper testing in both staging and production environments, verifying that the `vets-api` role has the appropriate permissions to interact with the S3 bucket.
