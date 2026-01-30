# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  # Job to find and expire PowerOfAttorneyRequests that are older than
  # EXPIRY_DURATION (60 days) and remain unresolved.
  class ExpirePowerOfAttorneyRequestsJob
    include Sidekiq::Job

    sidekiq_options retry: 3

    def perform
      threshold = calculate_expiration_threshold
      log_start(threshold)

      requests = find_eligible_requests(threshold)
      results = process_requests(requests)

      log_end(results)
    end

    private

    def calculate_expiration_threshold
      Time.current - PowerOfAttorneyRequest::EXPIRY_DURATION
    end

    def find_eligible_requests(threshold)
      PowerOfAttorneyRequest
        .unresolved
        .where(created_at: ..threshold)
    end

    def process_requests(requests_to_process)
      results = { expired: 0, errors: 0 }

      # Use find_each to process in batches, avoiding high memory usage.
      requests_to_process.find_each do |request|
        if attempt_expiration(request)
          results[:expired] += 1
        else
          results[:errors] += 1
        end
      end

      results
    end

    # Attempts to expire a single request, handling potential errors
    # Returns true on success, false on failure
    def attempt_expiration(request)
      expire_request(request)

      tags = ['resolution:expired', 'source:expire_job', "poa_code:#{request.power_of_attorney_holder_poa_code}"]

      monitor.track_duration(
        'vets_api.statsd.ar_poa_request_duration',
        from: request.created_at,
        tags:
      )

      monitor.track_count(
        'ar.poa.request.expired',
        tags:
      )

      true
    rescue => e
      log_expiration_error(request, e)
      false # Indicate failure
    end

    # Performs the actual expiration logic for a single request
    def expire_request(request)
      log_request_expiration(request)

      PowerOfAttorneyRequestExpiration.create_with_resolution!(
        power_of_attorney_request: request
      )
    end

    def log_start(threshold)
      Rails.logger.info(
        "#{self.class.name}: Starting job. Looking for unresolved requests created before #{threshold}."
      )
    end

    def log_request_expiration(request)
      Rails.logger.info(
        "#{self.class.name}: Expiring PowerOfAttorneyRequest ##{request.id}"
      )
    end

    def log_expiration_error(request, error)
      Rails.logger.error(
        "#{self.class.name}: Failed to expire PowerOfAttorneyRequest ##{request.id}. " \
        "Error: #{error.message}\n#{error.backtrace.join("\n")}"
      )
    end

    def log_end(results)
      Rails.logger.info(
        "#{self.class.name}: Finished job. Expired #{results[:expired]} requests. " \
        "Encountered #{results[:errors]} errors."
      )
    end

    def monitor
      @monitor ||= AccreditedRepresentativePortal::Monitoring.new(
        AccreditedRepresentativePortal::Monitoring::NAME,
        default_tags: ['job:expire_power_of_attorney_requests']
      )
    end
  end
end
