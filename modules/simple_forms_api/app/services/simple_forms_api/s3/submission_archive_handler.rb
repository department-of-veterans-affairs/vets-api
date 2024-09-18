# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionArchiveHandler < Utils
      def initialize(benefits_intake_uuids: [], parent_dir: 'vff-simple-forms') # rubocop:disable Lint/MissingSuper
        raise Common::Exceptions::ParameterMissing, 'benefits_intake_uuids' unless benefits_intake_uuids&.any?

        @benefits_intake_uuids = benefits_intake_uuids
        @parent_dir = parent_dir
        @presigned_urls = []
      rescue => e
        handle_error('SubmissionArchiveHandler initialization failed', e)
      end

      def upload
        archive_individual_submissions
        presigned_urls
      rescue => e
        handle_error('Archiving submission collection failed.', e)
      end

      private

      attr_reader :benefits_intake_uuids, :parent_dir, :presigned_urls

      def archive_individual_submissions
        benefits_intake_uuids.each_with_index do |uuid, i|
          log_info("Archiving submission: #{uuid} ##{i + 1} of #{benefits_intake_uuids.count} total submissions")
          presigned_urls << archive_submission(uuid)
        end
      end

      def archive_submission(benefits_intake_uuid)
        SubmissionArchiver.new(benefits_intake_uuid:, parent_dir:).upload
      end
    end
  end
end
