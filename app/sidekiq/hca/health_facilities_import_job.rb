# frozen_string_literal: true

module HCA
  class HealthFacilitiesImportJob
    include Sidekiq::Job

    def perform
      Rails.logger.info("Job started with #{HealthFacility.count} existing health facilities.")
      station_numbers = get_station_numbers

      # Filter on only health facilities and return hash with
      # name, station_number (also known as facility_id),
      # and postal_name (also known as state_code ex OH,MI)
      health_facilities = StdInstitutionFacility
                          .joins('INNER JOIN std_states AS s ON s.id = std_institution_facilities.street_state_id')
                          .where(station_number: station_numbers)
                          .pluck(
                            'std_institution_facilities.name, std_institution_facilities.station_number, s.postal_name'
                          )
                          .map do |name, station_number, postal_name|
        { name:, station_number:,
          postal_name: }
      end

      HealthFacility.insert_all(health_facilities, unique_by: :station_number) # rubocop:disable Rails/SkipsModelValidations

      Rails.logger.info("Job ended with #{HealthFacility.count} health facilities.")
      # StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.health_facilities_api_import_complete")
    rescue => e
      Rails.logger.error("Error occurred in #{self.class.name}: #{e.message}")
      raise "Failed to import health facilities in #{self.class.name}"
    end

    private

    def get_station_numbers
      facilities_client = FacilitiesApi::V2::Lighthouse::Client.new
      facility_ids = facilities_client.get_facility_ids(type: 'health')

      # Filter out `vha_` prefix and return array
      facility_ids.data.map { |s| s.sub(/^vha_/, '') }
    end
  end
end
