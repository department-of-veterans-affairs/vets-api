# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    class SubmissionArchiveHandler < Utils
      attr_reader :submission_ids, :parent_dir, :successes, :failures, :bundle_by_user

      def initialize(submission_ids:, **options) # rubocop:disable Lint/MissingSuper
        defaults = default_options.merge(options)

        @submission_ids = submission_ids
        @failures = []

        assign_instance_variables(defaults)
      end

      def run
        bundle_by_user ? process_by_user : process_individual_submissions
        cleanup_tmp_files
        parent_dir
      end

      private

      def default_options
        {
          bundle_by_user: true,
          file_path: nil, # file path for the PDF file to be archived
          metadata: {}, # pertinent metadata for original file upload/submission
          parent_dir: 'vff-simple-forms' # S3 bucket base directory where files live
        }
      end

      def submissions
        @submissions ||= FormSubmission.where(id: submission_ids)
      end

      def submissions_by_uuid
        @submissions_by_uuid ||= group_submissions_by_uuid
      end

      def group_submissions_by_uuid
        submissions.group_by(&:user_uuid).transform_values do |user_submissions|
          user_submissions.map(&:id)
        end
      end

      def process_by_user
        submissions_by_uuid.each do |uuid, submission_ids|
          log_info("Processing for user: #{uuid} with #{submission_ids.size} submission(s)", uuid:, submission_ids:)
          process_user_submissions(uuid, submission_ids)
        end
      end

      def process_individual_submissions
        submissions.each_with_index do |sub, idx|
          log_info(
            "Processing submission: #{sub.id} (non-grouped) ##{idx + 1} of #{submissions.count} total submissions",
            submission_id: sub.id, submission_count: submissions.count
          )
          process_submission(sub.id)
        end
      end

      def process_user_submissions(uuid, submission_ids)
        UserSubmissionArchiveHandler.new(uuid:, submission_ids:, parent_dir:).run
      rescue => e
        handle_error("User submission archiver failure: #{uuid}", e, uuid:)
      end

      def process_submission(submission_id)
        ArchiveSubmissionToPdf.new(
          file_path:,
          metadata:,
          parent_dir:,
          submission_id:
        ).run
      rescue => e
        handle_error("Submission archiver failure: #{submission_id}", e, submission_id:)
      end

      def cleanup_tmp_files
        system('rm -f tmp/* > /dev/null 2>&1')
      end
    end
  end
end
