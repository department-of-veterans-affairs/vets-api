# frozen_string_literal: true

# HealthFacilitiesImportJob
#

# This Sidekiq job imports and synchronizes VA health facility data from the Lighthouse API
# into the HealthFacility table. It ensures that the local database reflects the current
# set of health facilities, including removing facilities that no longer exist in the source.

# Why:
# - Keeps our health facility data up-to-date for downstream services and user-facing features.
# - Ensures data integrity by removing stale records.
# - Handles edge cases where environments may have missing reference data (see ensure_std_states_populated).

# How:
# - Fetches all health facilities from Lighthouse, paginating as needed.
# - Maps and transforms the data to match our schema.
# - Upserts (inserts or updates) all current facilities.
# - Deletes any facilities not present in the latest import.
# - Logs progress and errors for monitoring and debugging.

module HCA
  class HealthFacilitiesImportJob
    include Sidekiq::Job

    PER_PAGE = 1000

    # retry for 0d 4h 22m 38s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 10

    sidekiq_retries_exhausted do
      Rails.logger.error("[HCA] - #{HCA::HealthFacilitiesImportJob} failed with no retries left.")
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.health_facilities_import_job_failed_no_retries")
    end

    def perform
      Rails.logger.info("[HCA] - Job started with #{HealthFacility.count} existing health facilities.")
      ensure_std_states_populated

      facilities_from_lighthouse = get_facilities_from_lighthouse
      health_facilities = facilities_with_postal_names(facilities_from_lighthouse)

      HealthFacility.upsert_all(health_facilities, unique_by: :station_number) # rubocop:disable Rails/SkipsModelValidations
      delete_old_facilities(health_facilities)

      Rails.logger.info("[HCA] - Job ended with #{HealthFacility.count} health facilities.")
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.health_facilities_import_job_complete")
    rescue => e
      Rails.logger.error("[HCA] - Error occurred in #{self.class.name}: #{e.message}")
      raise "Failed to import health facilities in #{self.class.name}"
    end

    private

    def get_facilities_from_lighthouse
      facilities_client = FacilitiesApi::V2::Lighthouse::Client.new
      all_facilities = []
      page = 1

      loop do
        facilities = facilities_client.get_facilities(
          type: 'health',
          per_page: PER_PAGE,
          page:,
          mobile: false
        )
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

    # Ensure the std_states table is populated. The table is populated in a
    # daily job, but this ensures the table is populated in any environment
    # that the table may be empty in (review instances, new environment, locally)
    def ensure_std_states_populated
      return if StdState.exists?

      ::IncomeLimits::StdStateImport.new.perform
      raise 'StdStates missing – triggered import and retrying job'
    end

    # Filter on only health facilities and return hash with
    # name, station_number (also known as facility_id),
    # and postal_name (also known as state_code ex OH,MI)
    def facilities_with_postal_names(facilities_from_lighthouse)
      StdInstitutionFacility
        .includes(:street_state)
        .where(station_number: facilities_from_lighthouse.keys)
        .pluck(:station_number, 'std_states.postal_name')
        .map do |station_number, postal_name|
        {
          name: facilities_from_lighthouse[station_number][:name],
          station_number:,
          postal_name:
        }
      end
    end

    def delete_old_facilities(health_facilities)
      imported_station_numbers = health_facilities.pluck(:station_number)
      deleted_count = HealthFacility.where.not(station_number: imported_station_numbers).delete_all
      Rails.logger.info("[HCA] - Deleted #{deleted_count} health facilities not present in import.")
    end
  end
end
