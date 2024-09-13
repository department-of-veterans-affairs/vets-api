# frozen_string_literal: true

require 'csv'
require 'fileutils'

module SimpleFormsApi
  module S3
    class SubmissionArchiver < Utils
      attr_reader :local_submission_file_path

      class << self
        def fetch_presigned_url(benefits_intake_uuid)
          pdf = fetch_pdf(benefits_intake_uuid)
          generate_submission_presigned_url(pdf)
        end

        def fetch_s3_submission(benefits_intake_uuid)
          fetch_s3_object(benefits_intake_uuid, :submission)
        end

        def fetch_s3_archive(benefits_intake_uuid)
          fetch_s3_object(benefits_intake_uuid, :archive)
        end

        private

        def fetch_s3_object(benefits_intake_uuid, type)
          instance = new(benefits_intake_uuid:)
          instance.download(type)
        end
      end

      def initialize(benefits_intake_uuid: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @benefits_intake_uuid = benefits_intake_uuid
        @temp_directory_path = build_submission_archive(benefits_intake_uuid:, **defaults)

        assign_instance_variables(defaults)
      end

      def upload
        log_info("Uploading archive: #{benefits_intake_uuid} to S3 bucket")

        upload_temp_folder_to_s3
        cleanup
        s3_directory_path
      rescue => e
        handle_error("Failed archive upload: #{benefits_intake_uuid}", e, { benefits_intake_uuid: })
      end

      def download(type = :submission)
        log_info("Downloading #{type}: #{benefits_intake_uuid} to temporary directory: #{temp_directory_path}")
        send("download_#{type}_from_s3")
      rescue => e
        handle_error("Failed #{type} download: #{benefits_intake_uuid}", e, { benefits_intake_uuid: })
      end

      def cleanup
        FileUtils.rm_rf(temp_directory_path)
      end

      private

      attr_reader :benefits_intake_uuid, :file_path, :include_json_archive, :include_manifest, :include_text_archive,
                  :metadata, :parent_dir, :submission

      def default_options
        {
          attachments: [], # an array of attachment confirmation codes
          file_path: nil, # file path for the PDF file to be archived
          include_json_archive: true, # include the form data as a JSON object
          include_manifest: true, # include a CSV file containing Veteran ID & original submission datetime
          include_text_archive: true, # include the form data as a text file
          metadata: {}, # pertinent metadata for original file upload/submission
          parent_dir: 'vff-simple-forms' # S3 bucket base directory where files live
        }
      end

      def build_submission_archive(**)
        SubmissionArchiveBuilder.new(**).run
      end

      def upload_temp_folder_to_s3
        Find.find(temp_directory_path) do |path|
          next if File.directory?(path)

          relative_path = path.sub(temp_directory_path, '')

          File.open(path, 'rb') do |file|
            save_file_to_s3(file.read)
            generate_submission_presigned_url if relative_path == submission_pdf_filename
          end
        end
      end

      def download_archive_from_s3
        FileUtils.mkdir_p(temp_directory_path)

        s3_resource.bucket.objects(prefix: s3_directory_path).each do |object|
          local_file_path = File.join(temp_directory_path, object.key.sub(s3_directory_path, ''))
          FileUtils.mkdir_p(File.dirname("#{temp_directory_path}#{local_file_path}"))
          object.get(response_target: local_file_path)
        end
      end

      def download_submission_from_s3
        submission_object = s3_submission_object
        @local_submission_file_path = File.join(temp_directory_path, submission_object.key.sub(s3_directory_path, ''))
        FileUtils.mkdir_p(File.dirname(@local_submission_file_path))
        submission_object.get(response_target: @local_submission_file_path)
        @local_submission_file_path
      end

      def s3_submission_object
        s3_file_path = "#{s3_directory_path}/#{submission_pdf_filename}"
        s3_resource.bucket(target_bucket).object(s3_file_path)
      end

      def generate_submission_presigned_url
        s3_submission_object.presigned_url(:get, expires_in: 30.minutes.to_i)
      end

      def save_file_to_s3(content)
        s3_submission_object.tap { |obj| obj.put(body: content) }
      end

      def submission_pdf_filename
        @submission_pdf_filename ||= "form_#{JSON.parse(submission.form_data)['form_number']}.pdf"
      end

      def s3_directory_path
        @s3_directory_path ||= "#{parent_dir}/#{benefits_intake_uuid}"
      end

      def temp_directory_path
        @temp_directory_path ||= Rails.root.join("tmp/#{benefits_intake_uuid}-#{SecureRandom.hex}/").to_s
      end
    end
  end
end
