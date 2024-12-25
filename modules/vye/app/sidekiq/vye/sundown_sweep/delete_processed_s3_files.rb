# frozen_string_literal: true

module Vye
  class SundownSweep
    class DeleteProcessedS3Files
      include Sidekiq::Worker
      def perform
        return if Vye::CloudTransfer.holiday?

        logger.info('Vye::SundownSweep::DeleteProcessedS3Files: starting remove_aws_files_from_s3_buckets')
        Vye::CloudTransfer.remove_aws_files_from_s3_buckets
        logger.info('Vye::SundownSweep::DeleteProcessedS3Files: finished remove_aws_files_from_s3_buckets')
      end
    end
  end
end
