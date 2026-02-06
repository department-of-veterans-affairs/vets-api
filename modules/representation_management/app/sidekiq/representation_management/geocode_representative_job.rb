# frozen_string_literal: true

module RepresentationManagement
  # Geocodes a single representative (Veteran::Service::Representative or AccreditedIndividual)
  # by calling the model's geocode_and_update_location! method.
  # Handles both model types polymorphically.
  class GeocodeRepresentativeJob
    include Sidekiq::Job

    sidekiq_options retry: 3

    # Geocodes a representative record by calling its geocode_and_update_location! method.
    # @param model_class_name [String] The class name ('Veteran::Service::Representative' or 'AccreditedIndividual')
    # @param record_id [String, Integer] The record's primary key
    def perform(model_class_name, record_id)
      model_class = model_class_name.constantize
      record = model_class.find(record_id)

      record.geocode_and_update_location!
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Record not found for #{model_class_name}##{record_id}: #{e.message}")
      # Don't retry if record doesn't exist
    rescue => e
      Rails.logger.error("Geocode job failed for #{model_class_name}##{record_id}: #{e.message}")
      raise # Let Sidekiq retry
    end
  end
end
