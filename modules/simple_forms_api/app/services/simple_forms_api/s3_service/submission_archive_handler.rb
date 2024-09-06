# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    class SubmissionArchiveHandler < SimpleFormsApi::S3Service::Utils
      attr_reader :submission_ids, :parent_dir, :successes, :failures,
                  :bundle_by_user, :run_quiet, :quiet_upload_failures, :quiet_pdf_failures

      def initialize(submission_ids:, **options)
        defaults = default_options.merge(options)

        @submission_ids = submission_ids
        @parent_dir = defaults[:parent_dir]
        @bundle_by_user = defaults[:bundle_by_user]
        @run_quiet = defaults[:run_quiet]
        @quiet_upload_failures = defaults[:quiet_upload_failures]
        @quiet_pdf_failures = defaults[:quiet_pdf_failures]
        @failures = []
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
          parent_dir: 'wipn8923-test',
          quiet_pdf_failures: false, # granular control over how user processing raises errors
          quiet_upload_failures: false, # granular control over how user processing raises errors
          run_quiet: true # silence but record errors until the end
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
        handle_error("User failure: #{uuid}", e, uuid:)
      end

      def process_submission(submission_id)
        ArchiveSubmissionToPdf.new(
          submission_id:,
          parent_dir:,
          quiet_pdf_failures:,
          quiet_upload_failures:
        ).run
      rescue => e
        handle_error("Submission failure: #{submission_id}", e, submission_id:)
      end

      def handle_error(message, error, context)
        raise unless run_quiet

        log_error(message, error, context)
        failures << { context => error }
      end

      def cleanup_tmp_files
        system('rm -f tmp/* > /dev/null 2>&1')
      end
    end
  end
end
