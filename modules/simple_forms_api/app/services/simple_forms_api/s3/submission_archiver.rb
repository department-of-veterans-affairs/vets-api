# frozen_string_literal: true

require 'csv'
require 'fileutils'

module SimpleFormsApi
  module S3
    class SubmissionArchiver < Utils
      class << self
        def fetch_presigned_url(benefits_intake_uuid)
          pdf = fetch_pdf(benefits_intake_uuid)
          sign_s3_file_url(pdf)
        end

        # TODO: these instance methods are private, assess and update
        def fetch_pdf(benefits_intake_uuid)
          instance = new(benefits_intake_uuid:)
          instance.fetch_submission_pdf(benefits_intake_uuid)
        end

        # TODO: these instance methods are private, assess and update
        def fetch_s3_submission(benefits_intake_uuid)
          instance = new(benefits_intake_uuid:)
          instance.download_folder_from_s3
          instance.temp_directory_path
        end
      end

      def initialize(benefits_intake_uuid: nil, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @benefits_intake_uuid = benefits_intake_uuid
        @temp_directory_path = build_submission_archive(benefits_intake_uuid:, **defaults)

        assign_instance_variables(defaults)
      end

      def run
        log_info("Processing submission: #{benefits_intake_uuid}")

        upload_temp_folder_to_s3

        FileUtils.rm_f(temp_directory_path)

        output_directory_path
      rescue => e
        handle_error("Failed submission: #{benefits_intake_uuid}", e, { benefits_intake_uuid: })
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
          s3_path = "#{output_directory_path}/#{relative_path}"

          File.open(path, 'rb') do |file|
            pdf = save_file_to_s3(s3_path, file.read)
            sign_s3_file_url(pdf) if relative_path == submission_pdf_filename
          end
        end
      end

      def download_folder_from_s3
        FileUtils.mkdir_p(temp_directory_path)

        s3_resource.bucket.objects(prefix: output_directory_path).each do |object|
          local_file_path = File.join(temp_directory_path, object.key.sub(output_directory_path, ''))
          FileUtils.mkdir_p(File.dirname("#{temp_directory_path}#{local_file_path}"))
          object.get(response_target: local_file_path)
        end
      end

      def fetch_submission_pdf
        path = "#{output_directory_path}/#{submission_pdf_filename}"
        s3_resource.bucket(target_bucket).object(path)
      end

      def submission_pdf_filename
        @submission_pdf_filename ||= "form_#{submission.form_data['form_number']}.pdf"
      end

      def sign_s3_file_url(pdf)
        pdf.presigned_url(:get, expires_in: 30.minutes.to_i)
      end

      def save_file_to_s3(path, content)
        s3_resource.bucket(target_bucket).object(path).tap { |obj| obj.put(body: content) }
      end

      def output_directory_path
        @output_directory_path ||= "#{parent_dir}/#{benefits_intake_uuid}"
      end

      def temp_directory_path
        @temp_directory_path ||= Rails.root.join("tmp/#{benefits_intake_uuid}-#{SecureRandom.hex}/").to_s
      end
    end
  end
end
