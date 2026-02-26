# frozen_string_literal: true

module RepresentationManagement
  # Enqueues geocoding jobs for all Veteran::Service::Representative and AccreditedIndividual
  # records that have stale fallback_location_updated_at timestamps.
  # Schedules individual geocoding jobs with 2 second delays to respect rate limits.
  class EnqueueStaleGeocodingJob
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2
    STALE_THRESHOLD_DAYS = 14

    def perform
      total_count = 0

      # Process Veteran::Service::Representative records
      total_count += enqueue_for_model(Veteran::Service::Representative, :representative_id, total_count)

      # Process AccreditedIndividual records
      enqueue_for_model(AccreditedIndividual, :id, total_count)
    end

    private

    # Enqueues geocoding jobs for a specific model class
    # @param model_class [Class] The ActiveRecord model class to process
    # @param id_field [Symbol] The primary key field name for the model
    # @param offset [Integer] The starting offset for job scheduling
    # @return [Integer] The number of records processed
    def enqueue_for_model(model_class, id_field, offset)
      records = model_class.where('fallback_location_updated_at < ?', STALE_THRESHOLD_DAYS.days.ago)

      count = 0
      records.find_each.with_index do |record, index|
        delay_seconds = (offset + index) * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(
          delay_seconds.seconds,
          model_class.name,
          record.send(id_field)
        )
        count += 1
      end

      count
    end
  end
end
