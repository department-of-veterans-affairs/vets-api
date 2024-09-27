# frozen_string_literal: true

require 'ihub/configuration'

module SimpleFormsApi
  module FormSubmissionRemediation
    class Configuration
      class Base
        attr_reader :id_type, :include_manifest, :include_metadata, :parent_dir, :required_submission_data

        def initialize
          @id_type = 'benefits_intake_uuid'
          @include_manifest = true  # Include a CSV file containing manifest data
          @include_metadata = false # Include a JSON file containing metadata
          @parent_dir = '/'         # The base directory in the S3 bucket where the archive will be stored
          @required_submission_data = %i[submission file_path attachments metadata]
        end

        def archive_builder
          SimpleFormsApi::S3::SubmissionArchiveBuilder
        end

        def archiver
          SimpleFormsApi::S3::SubmissionArchiver
        end

        def submission_builder
          SimpleFormsApi::S3::SubmissionBuilder
        end

        # If overriding this, s3_setting method doesn't have to be set
        def uploader
          VeteranFacingFormsRemediationUploader
        end

        def attachment_type
          PersistentAttachment
        end

        # The temporary directory where form submissions will be
        # hydrated and stored. This directory will automatically
        # be deleted once the archive process completes
        def temp_directory_path
          @temp_directory_path ||= Rails.root.join("tmp/#{SecureRandom.hex}-archive/").to_s
        end

        # Used in the VeteranFacingFormsRemediationUploader
        def s3_settings
          vff_simple_forms.aws
        end

        def s3_resource
          @s3_resource ||= uploader.new_s3_resource
        end

        def target_bucket
          @target_bucket ||= uploader.s3_bucket
        end

        def log_info(message, **details)
          Rails.logger.info(message, details)
        end

        def log_error(message, error, **details)
          Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
        end

        def handle_error(message, error, **details)
          log_error(message, error, **details)
          raise error
        end
      end
    end
  end
end
