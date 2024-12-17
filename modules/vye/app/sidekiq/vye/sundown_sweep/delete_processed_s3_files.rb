# frozen_string_literal: true

module Vye
  class SundownSweep
    class DeleteProcessedS3Files
      include Sidekiq::Worker
      def perform
<<<<<<< HEAD
=======
        return if Vye::CloudTransfer.holiday?

>>>>>>> ef3c0288176bba86adfb7abaf6e3a2c9bd88c1aa
        logger.info('Beginning: remove_aws_files_from_s3_buckets')
        Vye::CloudTransfer.remove_aws_files_from_s3_buckets
        logger.info('Finishing: remove_aws_files_from_s3_buckets')
      end
    end
  end
end
