# frozen_string_literal: true

module Vye
  class SundownSweep
    class DeleteProcessedS3Files
      include Sidekiq::Worker
      def perform
        return if Vye::CloudTransfer.holiday?

        logger.info('Beginning: remove_aws_files_from_s3_buckets')
        Vye::CloudTransfer.remove_aws_files_from_s3_buckets
        logger.info('Finishing: remove_aws_files_from_s3_buckets')
      end
    end
  end
end
