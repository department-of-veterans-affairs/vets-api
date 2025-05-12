# frozen_string_literal: true

require 'sidekiq'

# This job removes IvcChampvaForm records that are older than 60 days based on updated_at timestamp
module IvcChampva
  class OldRecordsCleanupJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    BATCH_SIZE = 500
    CLEANUP_THRESHOLD_DAYS = 60

    def perform
      return unless Settings.ivc_forms.sidekiq.old_records_cleanup_job.enabled
      return unless Flipper.enabled?(:champva_old_records_cleanup_job)

      total_deleted = 0

      # Process in batches to avoid memory issues
      find_old_records_in_batches do |batch|
        batch_count = delete_old_records(batch)
        total_deleted += batch_count
      end

      Rails.logger.info("IvcChampva::OldRecordsCleanupJob completed: #{total_deleted} records deleted")
    end

    private

    def find_old_records_in_batches(&)
      # Use in_batches to process records in manageable chunks
      IvcChampvaForm.where('updated_at < ?', CLEANUP_THRESHOLD_DAYS.days.ago)
                    .in_batches(of: get_batch_size, &)
    end

    def get_batch_size
      # Production code will use the constant, but this method can be mocked in tests
      BATCH_SIZE
    end

    def delete_old_records(records)
      records.destroy_all.count
    end
  end
end
