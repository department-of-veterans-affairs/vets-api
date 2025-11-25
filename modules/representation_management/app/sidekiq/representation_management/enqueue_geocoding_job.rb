# frozen_string_literal: true

module RepresentationManagement
  # Enqueues geocoding jobs for all Veteran::Service::Representative and AccreditedIndividual
  # records that are missing lat, long, or location data.
  # Schedules individual geocoding jobs with 2 second delays to respect rate limits.
  class EnqueueGeocodingJob
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2

    def perform
      total_count = 0
      offset = 0

      # Process Veteran::Service::Representative records
      offset = enqueue_for_model(Veteran::Service::Representative, :representative_id, offset)
      total_count += offset

      # Process AccreditedIndividual records
      individual_count = enqueue_for_model(AccreditedIndividual, :id, offset)
      total_count += individual_count

      Rails.logger.info("Enqueued #{total_count} geocoding jobs")
    end

    private

    # Enqueues geocoding jobs for a specific model class
    # @param model_class [Class] The ActiveRecord model class to process
    # @param id_field [Symbol] The primary key field name for the model
    # @param offset [Integer] The starting offset for job scheduling
    # @return [Integer] The number of records processed
    def enqueue_for_model(model_class, id_field, offset)
      records = model_class
                .where(lat: nil)
                .or(model_class.where(long: nil))
                .or(model_class.where(location: nil))

      records.find_each.with_index do |record, index|
        delay_seconds = (offset + index) * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(
          delay_seconds.seconds,
          model_class.name,
          record.send(id_field)
        )
      end

      records.count
    end
  end
end
