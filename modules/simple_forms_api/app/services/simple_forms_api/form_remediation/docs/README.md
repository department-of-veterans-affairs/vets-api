# Form Remediation Service

This service is designed to remediate form submissions which have failed submission and are over two weeks old.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Settings](#settings)
- [AWS S3 Bucket Setup](#aws-s3-bucket-setup)
- [Configuration](#configuration)
- [Usage](#usage)
- [Extending Functionality](#extending-functionality)

---

## Getting Started

This service has been built in such a way that almost all aspects of the workflow can be configured or extended, depending upon your team's needs.

---

## Settings

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

---

## Configuration

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

---

## Usage

The Veteran Facing Forms team currently calls the bulk processing job utilizing [a rake task](../../../../../../simple_forms_api/lib/tasks/archive_forms_by_uuid.rake). Your team may choose to call it a different way but this is how we handle it.

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
handler = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.perform(ids: benefits_intake_uuids, config:)
presigned_urls = handler.upload(type: :remediation)
```
