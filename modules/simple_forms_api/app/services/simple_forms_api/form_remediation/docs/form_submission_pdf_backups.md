# Form Submission PDF Backups

This documentation covers the setup and usage of the PDF upload/download solution, designed to handle individual form submissions as PDF files within an AWS S3 bucket.

---

## Table of Contents

- [Form Submission PDF Backups](#form-submission-pdf-backups)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Settings](#settings)
    - [Configuration](#configuration)
  - [Usage](#usage)
    - [Individual Processing](#individual-processing)
    - [S3 Pre-Signed URL Retrieval](#s3-pre-signed-url-retrieval)
  - [Extending Functionality](#extending-functionality)
    - [Overrideable Classes](#overrideable-classes)
    - [Directory and File Structure](#directory-and-file-structure)
      - [Structure Overview](#structure-overview)
    - [Naming Conventions](#naming-conventions)
  - [AWS S3 Bucket Setup](#aws-s3-bucket-setup)

---

## Getting Started

This solution is flexible and can be customized to meet team-specific requirements for handling form submissions.

### Settings

To enable this functionality, the only required settings for AWS S3 are `region` and `bucket`. These should be configured as follows in your `Settings`:

```yml
bucket: <YOUR_TEAM_BUCKET>
region: <YOUR_TEAM_REGION>
```

If your team has different AWS S3 configurations, you can override these settings by implementing a custom `s3_settings` method within your configuration class.

Example:

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

For additional guidance on adding settings, refer to the [Platform Documentation](https://depo-platform-documentation.scrollhelp.site/developer-docs/settings).

### Configuration

To create a custom configuration, subclass the Base configuration and implement the `s3_settings` method:

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

class NewConfig < SimpleFormsApi::FormRemediation::Configuration::Base
  def s3_settings
    Settings.<YOUR_TEAM>.<AWS_S3_SETTINGS>
  end
end
```

By default, the solution uses the `:benefits_intake_uuid` identifier to query `FormSubmission`. You can change this by specifying a different `id_type` in your configuration.

---

## Usage

### Individual Processing

To handle a single PDF upload for a form submission, instantiate the `S3Client` directly with the appropriate configuration and submission ID. For backup purposes, specify `type: :submission` during initialization. This ensures that only the original form PDF is uploaded and a presigned URL is generated:

```ruby
config = YourTeamsConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: <YOUR_SUBMISSION_ID>, type: :submission)
client.upload
```

### S3 Pre-Signed URL Retrieval

To handle a single PDF download for an already archived form submission, call the `fetch_presigned_url` class method on the `S3Client` class with the appropriate configuration and submission ID:

```ruby
config = YourTeamsConfig.new
SimpleFormsApi::FormRemediation::S3Client.fetch_presigned_url(<YOUR_SUBMISSION_ID>, config:)
```

---

## Extending Functionality

Each component of this solution can be extended or customized to meet team requirements.

1. Review extensible components in the [Base Configuration](../../../../../../../lib/simple_forms_api/form_remediation/configuration/base.rb).
2. Create subclasses for required functionality.
3. Register the subclass in your configuration:

Extending the uploader:

```ruby
# frozen_string_literal: true

require 'simple_forms_api/form_remediation/uploader'

class NewUploader < SimpleFormsApi::FormRemediation::Uploader
  def size_range
    (1.byte)...(50.megabytes)
  end
end
```

Using the new uploader within your own team's configuration:

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

Instantiate the client with your team's configuration:

```ruby
config = NewConfig.new
client = SimpleFormsApi::FormRemediation::S3Client.new(config:, id: <YOUR_SUBMISSION_ID>, type: :submission)
client.upload
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
└── submission/
    ├── 10.28.24-Form21-4142/
    │   └── 10.28.24_form_21-4142_vagov_abc123.pdf  # Original form PDF only
    └── 10.28.24-Form40-10007/
        └── 10.28.24_form_40-10007_vagov_abc123.pdf
```

### Naming Conventions

- **Dated Directory**: Follows `<MM.DD.YY>-Form<FormNumber>` format.
- **PDF Files**: Named `<MM.DD.YY>_form_<FormNumber>_vagov_<ID>.pdf`.

This structure and naming convention provides clear organization, helping locate specific submission archives by type, date, and form number.

---

## AWS S3 Bucket Setup

- [Please refer to the AWS S3 Bucket Setup Documentation here.](aws_s3_bucket_setup.md)
