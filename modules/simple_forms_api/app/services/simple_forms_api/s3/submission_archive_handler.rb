# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionArchiveHandler < Utils
      PROGRESS_FILE_PATH = '/tmp/submission_archive_progress.json'

      def initialize(benefits_intake_uuids: [], parent_dir: '') # rubocop:disable Lint/MissingSuper
        raise Common::Exceptions::ParameterMissing, 'benefits_intake_uuids' unless benefits_intake_uuids&.any?

        @benefits_intake_uuids = benefits_intake_uuids
        @parent_dir = parent_dir
        @presigned_urls = []
        load_progress
      rescue => e
        handle_error('SubmissionArchiveHandler initialization failed', e)
      end

      def upload(type: :remediation)
        @type = type

        archive_individual_submissions
        presigned_urls = read_urls_from_file
        cleanup
        presigned_urls
      rescue => e
        handle_error('Archiving submission collection failed.', e)
      end

      private

      attr_reader :benefits_intake_uuids, :parent_dir, :presigned_urls, :type

      def cleanup
        FileUtils.rm_rf(PROGRESS_FILE_PATH)
      end

      def load_progress
        if File.exist?(PROGRESS_FILE_PATH)
          progress_data = JSON.parse(File.read(PROGRESS_FILE_PATH))
          @processed_uuids = progress_data['uuids']
          @presigned_urls = progress_data['urls']
        else
          @processed_uuids = []
          @presigned_urls = []
        end
      end

      def write_progress
        progress_data = { uuids: @processed_uuids, urls: @presigned_urls }
        File.write(PROGRESS_FILE_PATH, JSON.pretty_generate(progress_data))
      end

      def read_urls_from_file
        return [] unless File.exist?(PROGRESS_FILE_PATH)

        progress_data = JSON.parse(File.read(PROGRESS_FILE_PATH))
        progress_data['urls']
      end

      def archive_individual_submissions
        benefits_intake_uuids.each_with_index do |uuid, i|
          next if @processed_uuids.include? uuid

          log_info("Archiving submission: #{uuid} ##{i + 1} of #{benefits_intake_uuids.count} total submissions")
          presigned_url = archive_submission(uuid)
          @presigned_urls << presigned_url
          @processed_uuids << uuid
          write_progress
        end
      end

      def archive_submission(benefits_intake_uuid)
        SubmissionArchiver.new(benefits_intake_uuid:, parent_dir:).upload(type:)
      end
    end
  end
end
