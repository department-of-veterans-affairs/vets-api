# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class SubmissionArchiveHandler
      include FileUtilities

      PROGRESS_FILE_PATH = '/tmp/submission_archive_progress.json'

      def initialize(ids: [], config:)
        raise Common::Exceptions::ParameterMissing, 'ids' unless ids&.any?

        @ids = ids
        @config = config
        @parent_dir = config.parent_dir
        @presigned_urls = []
        load_progress
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def upload(type: :remediation)
        @type = type

        archive_individual_submissions
        presigned_urls = read_urls_from_file
        cleanup(PROGRESS_FILE_PATH)
        presigned_urls
      rescue => e
        config.handle_error("Archiving #{type} collection failed.", e)
      end

      private

      attr_reader :config, :ids, :parent_dir, :presigned_urls, :type

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
        ids.each_with_index do |uuid, i|
          next if @processed_uuids.include? uuid

          config.log_info("Archiving #{type}: #{uuid} ##{i + 1} of #{ids.count} total submissions")
          presigned_url = archive_submission(uuid)
          @presigned_urls << presigned_url
          @processed_uuids << uuid
          write_progress
        end
      end

      def archive_submission(id)
        config.s3_client.new(id:, parent_dir:, type:).upload
      end
    end
  end
end
