# frozen_string_literal: true

module RepresentationManagement
  # Enqueues geocoding jobs for all Veteran::Service::Representative and AccreditedIndividual
  # records that are missing lat, long, or location data.
  # Schedules individual geocoding jobs with 2 second delays to respect rate limits.
  class EnqueueGeocodingJob
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2

    def perform
      offset = 0

      # Process Veteran::Service::Representative records
      veteran_reps = Veteran::Service::Representative
                     .where(lat: nil)
                     .or(Veteran::Service::Representative.where(long: nil))
                     .or(Veteran::Service::Representative.where(location: nil))

      veteran_reps.find_each.with_index do |rep, index|
        delay_seconds = (offset + index) * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(
          delay_seconds.seconds,
          'Veteran::Service::Representative',
          rep.representative_id
        )
      end

      offset += veteran_reps.count

      # Process AccreditedIndividual records
      accredited_individuals = AccreditedIndividual
                               .where(lat: nil)
                               .or(AccreditedIndividual.where(long: nil))
                               .or(AccreditedIndividual.where(location: nil))

      accredited_individuals.find_each.with_index do |individual, index|
        delay_seconds = (offset + index) * RATE_LIMIT_SECONDS
        GeocodeRepresentativeJob.perform_in(
          delay_seconds.seconds,
          'AccreditedIndividual',
          individual.id
        )
      end

      Rails.logger.info("Enqueued #{veteran_reps.count + accredited_individuals.count} geocoding jobs")
    end
  end
end
