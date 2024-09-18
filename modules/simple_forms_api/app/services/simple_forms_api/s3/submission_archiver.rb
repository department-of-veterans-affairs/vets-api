# frozen_string_literal: true

require 'csv'
require 'fileutils'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiver < Utils
      class << self
        def fetch_presigned_url(benefits_intake_uuid)
          new(benefits_intake_uuid:).generate_presigned_url
        end

        def fetch_s3_submission(benefits_intake_uuid)
          new(benefits_intake_uuid:).download(:submission)
        end

        def fetch_s3_archive(benefits_intake_uuid)
          new(benefits_intake_uuid:).download(:archive)
        end
      end

      def initialize(parent_dir: 'vff-simple-forms', **options) # rubocop:disable Lint/MissingSuper
        @parent_dir = parent_dir
        defaults = default_options.merge(options)
        @temp_directory_path = build_submission_archive(**defaults)
        assign_instance_variables(defaults)
      rescue => e
        handle_error('SubmissionArchiver initialization failed', e)
      end

      def upload
        log_info("Uploading archive: #{benefits_intake_uuid} to S3 bucket")

        upload_temp_folder_to_s3
        cleanup
        generate_presigned_url
      rescue => e
        handle_error("Failed archive upload: #{benefits_intake_uuid}", e)
      end

      def download(type = :submission)
        log_info("Downloading #{type}: #{benefits_intake_uuid} to temporary directory: #{temp_directory_path}")
        send("download_#{type}_from_s3")
      rescue => e
        handle_error("Failed #{type} download: #{benefits_intake_uuid}", e)
      end

      def cleanup
        FileUtils.rm_rf(temp_directory_path)
      end

      private

      attr_reader :benefits_intake_uuid, :parent_dir, :submission

      def default_options
        {
          attachments: nil,           # The confirmation codes of any attachments which were originally submitted
          benefits_intake_uuid: nil,  # The UUID returned from the Benefits Intake API upon original submission
          file_path: nil,             # The local path where the submission PDF is stored
          metadata: nil,              # Data appended to the original submission headers
          submission: nil             # The FormSubmission object representing the original data payload submitted
        }
      end

      def build_submission_archive(**)
        SubmissionArchiveBuilder.new(**).run
      end

      def upload_temp_folder_to_s3
        Dir.glob("#{temp_directory_path}/**/*").each do |path|
          next if File.directory?(path)

          File.open(path, 'rb') { |file| save_file_to_s3(file.read) }
        end
      end

      def download_archive_from_s3
        archive_object_collection.each do |object|
          local_file_path = build_local_file_path(object.key)
          object.get(response_target: local_file_path)
        end
      end

      def download_submission_from_s3
        submission_object.get(response_target: local_submission_file_path)
        local_submission_file_path
      end

      def build_local_file_path(s3_key)
        local_path = s3_key.sub(s3_directory_path, '')
        FileUtils.mkdir_p(File.dirname("#{temp_directory_path}/#{local_path}"))
        "#{temp_directory_path}/#{local_path}"
      end

      def generate_presigned_url
        submission_object.presigned_url(:get, expires_in: 30.minutes.to_i)
      end

      def save_file_to_s3(content)
        submission_object.tap { |obj| obj.put(body: content) }
      end

      def submission_object
        s3_resource.bucket(target_bucket).object(s3_submission_file_path)
      end

      def archive_object_collection
        s3_resource.bucket(target_bucket).objects(prefix: s3_directory_path)
      end

      def s3_submission_file_path
        "#{s3_directory_path}/#{submission_pdf_filename}"
      end

      def submission_pdf_filename
        submission_form_number = JSON.parse(submission.form_data)['form_number']
        @submission_pdf_filename ||= "form_#{submission_form_number}.pdf"
      end

      def s3_directory_path
        @s3_directory_path ||= "#{parent_dir}/#{benefits_intake_uuid}"
      end

      def local_submission_file_path
        @local_submission_file_path ||= build_local_file_path(s3_submission_file_path)
      end
    end
  end
end
