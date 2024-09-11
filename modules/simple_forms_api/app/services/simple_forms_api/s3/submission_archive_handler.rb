# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionArchiveHandler < Utils
      attr_reader :attachments, :benefits_intake_uuids, :parent_dir, :metadata, :file_path

      def initialize(benefits_intake_uuids: [], **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @benefits_intake_uuids = benefits_intake_uuids

        assign_instance_variables(defaults)
      end

      def run
        process_individual_submissions
        cleanup_tmp_files
        parent_dir
      end

      private

      def default_options
        {
          attachments: [], # an array of attachment confirmation codes
          file_path: nil, # file path for the PDF file to be archived
          metadata: {}, # pertinent metadata for original file upload/submission
          parent_dir: 'vff-simple-forms' # S3 bucket base directory where files live
        }
      end

      def submissions
        @submissions ||= FormSubmission.where(benefits_intake_uuid: benefits_intake_uuids)
      end

      def process_individual_submissions
        submissions.each_with_index do |sub, idx|
          message = "Processing submission: #{sub.benefits_intake_uuid} (non-grouped)" \
                    "##{idx + 1} of #{submissions.count} total submissions"
          log_info(message, benefits_intake_uuid: sub.benefits_intake_uuid, submission_count: submissions.count)
          process_submission(sub.benefits_intake_uuid)
        end
      end

      def process_submission(benefits_intake_uuid)
        SubmissionArchiver.new(attachments:, file_path:, metadata:, parent_dir:, benefits_intake_uuid:).run
      rescue => e
        handle_error("Submission archiver failure: #{benefits_intake_uuid}", e, benefits_intake_uuid:)
      end

      def cleanup_tmp_files
        system('rm -f tmp/* > /dev/null 2>&1')
      end
    end
  end
end
