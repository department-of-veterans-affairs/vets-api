# frozen_string_literal: true

module HCA
  class HealthFacilitiesImportJob
    include Sidekiq::Job

    PER_PAGE = 1000

    def perform
      Rails.logger.info("Job started with #{HealthFacility.count} existing health facilities.")
      facilities_from_lighthouse = get_facilities_from_lighthouse

      # Filter on only health facilities and return hash with
      # name, station_number (also known as facility_id),
      # and postal_name (also known as state_code ex OH,MI)
      health_facilities = StdInstitutionFacility
                          .joins('INNER JOIN std_states AS s ON s.id = std_institution_facilities.street_state_id')
                          .where(station_number: facilities_from_lighthouse.keys)
                          .pluck('std_institution_facilities.station_number, s.postal_name')
                          .map do |station_number, postal_name|
        {
          name: facilities_from_lighthouse[station_number][:name],
          station_number:,
          postal_name:
        }
      end

      HealthFacility.insert_all(health_facilities, unique_by: :station_number) # rubocop:disable Rails/SkipsModelValidations

      Rails.logger.info("Job ended with #{HealthFacility.count} health facilities.")
      # StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.health_facilities_api_import_complete")
    rescue => e
      Rails.logger.error("Error occurred in #{self.class.name}: #{e.message}")
      raise "Failed to import health facilities in #{self.class.name}"
    end

    private

    def get_facilities_from_lighthouse
      facilities_client = FacilitiesApi::V2::Lighthouse::Client.new
      all_facilities = []
      page = 1

      loop do
        facilities = facilities_client.get_facilities(type: 'health', per_page: PER_PAGE, page:)
        all_facilities.concat(facilities.map do |facility|
          {
            id: facility.id.sub(/^vha_/, ''), # Transform id by stripping "vha_" prefix
            name: facility.name
          }
        end)

        break if facilities.size < PER_PAGE # Stop when we get less than per_page results

        page += 1
      end

      all_facilities.index_by { |facility| facility[:id] }
    end
  end
end
