# frozen_string_literal: true

module Vye
  class SundownSweep
    class DeleteProcessedS3Files
      include Sidekiq::Worker
      def perform
        if Vye::CloudTransfer.holiday?
          logger.info("Vye::SundownSweep::DeleteProcessedS3Files: holiday detected, job run at: #{Time.zone.now}")
          return
        end

        logger.info('Vye::SundownSweep::DeleteProcessedS3Files: starting remove_aws_files_from_s3_buckets')
        Vye::CloudTransfer.remove_aws_files_from_s3_buckets
        logger.info('Vye::SundownSweep::DeleteProcessedS3Files: finished remove_aws_files_from_s3_buckets')
      end
    end
  end
end
