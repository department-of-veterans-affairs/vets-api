# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class Base
        attr_reader :id_type, :include_manifest, :include_metadata, :parent_dir, :presign_s3_url

        def initialize
          @id_type = :benefits_intake_uuid  # The field to query the FormSubmission by
          @include_manifest = true          # Include a CSV file containing manifest data
          @include_metadata = false         # Include a JSON file containing form submission metadata
          @parent_dir = ''                  # The base directory in the S3 bucket where the archive will be stored
          @presign_s3_url = true            # Once archived to S3, the service should generate & return a presigned_url
        end

        # Override to inject your team's own submission archive
        def submission_archive_class
          SimpleFormsApi::FormRemediation::SubmissionArchive
        end

        # Override to inject your team's own s3 client
        def s3_client
          SimpleFormsApi::FormRemediation::S3Client
        end

        # Override to inject your team's own submission data builder
        def remediation_data_class
          SimpleFormsApi::FormRemediation::SubmissionRemediationData
        end

        # Override to inject your team's own file uploader
        # If overriding this, s3_settings method doesn't have to be set
        def uploader_class
          SimpleFormsApi::FormRemediation::Uploader
        end

        # The FormSubmission model to query against
        def submission_type
          FormSubmission
        end

        # The attachment model to query for form submission attachments
        def attachment_type
          PersistentAttachment
        end

        # The temporary directory where form submissions will be
        # hydrated and stored. This directory will automatically
        # be deleted once the archive process completes
        def temp_directory_path
          Rails.root.join("tmp/#{SecureRandom.hex}-archive/").to_s
        end

        # Used in the SimpleFormsApi::FormRemediation::Uploader S3 uploader
        def s3_settings
          raise NotImplementedError, 'Class must implement s3_settings method'
        end

        # Utility method, override to add your own team's preferred logging approach
        def log_info(message, **details)
          Rails.logger.info({ message: }.merge(details))
        end

        # Utility method, override to add your own team's preferred logging approach
        def log_error(message, error, **details)
          Rails.logger.error({ message:, error: error.message, backtrace: error.backtrace.first(5) }.merge(details))
        end

        # Utility method, override to add your own team's preferred logging approach
        def handle_error(message, error, **details)
          log_error(message, error, **details)
          raise error
        end
      end
    end
  end
end
