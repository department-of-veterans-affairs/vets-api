# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    class UserSubmissionArchiveHandler < Utils
      attr_reader :uuid, :user_dir, :submission_ids

      def initialize(uuid:, submission_ids:, parent_dir: 'vff-simple-forms') # rubocop:disable Lint/MissingSuper
        @submission_ids = submission_ids
        @uuid = uuid
        @user_dir = build_user_directory(parent_dir)
      end

      def run
        log_info("Starting archive for user: #{uuid}, Submissions: #{submission_ids}")
        write_user_submissions
        log_info("Archive completed for user: #{uuid}")
        user_dir
      rescue => e
        handle_error("Error in archive process for user: #{uuid}", e)
      end

      private

      def build_user_directory(parent_dir)
        "#{parent_dir}/#{uuid}"
      end

      def write_user_submissions
        submissions.each do |submission|
          archive_submission(submission)
        rescue => e
          log_error("Failed to archive submission: #{submission.id} for user: #{uuid}", e)
        end
      end

      def archive_submission(submission)
        log_info("Processing submission: #{submission.id}")
        ArchiveSubmissionToPdf.new(submission:, parent_dir: user_dir).run
      end

      def submissions
        @submissions ||= fetch_submissions
      end

      def fetch_submissions
        FormSubmission.where(id: submission_ids).tap do |subs|
          log_info("Fetched #{subs.count} submissions for user: #{uuid}")
        end
      end
    end
  end
end
