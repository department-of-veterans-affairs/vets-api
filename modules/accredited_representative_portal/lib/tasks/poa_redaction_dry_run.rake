# frozen_string_literal: true

namespace :accredited_representative_portal do
  namespace :poa_redaction do
    desc 'Observes (Dry Run) which PowerOfAttorneyRequests would be selected for redaction " \
    "without performing the action.'
    task dry_run: :environment do
      puts 'Starting redaction dry run observation...'
      Rails.logger.info('[RedactionDryRun] Starting dry run...')

      # Instantiate the job to access its logic
      job_instance = AccreditedRepresentativePortal::RedactPowerOfAttorneyRequestsJob.new
      eligible_requests = []
      error_occurred = false

      begin
        # --- Find Eligible Requests ---
        # We need to call the private method from the job that finds eligible requests.
        # Note: This couples the Rake task to the job's internal implementation.
        # If the job's private methods change structure, this task may need updating.
        eligible_requests = job_instance.send(:eligible_requests_for_redaction)

        # Ensure it's loaded if it's an ActiveRecord::Relation
        eligible_requests.load if eligible_requests.is_a?(ActiveRecord::Relation)

        total_eligible = eligible_requests.size

        puts "[RedactionDryRun] Found #{total_eligible} request(s) " \
             'eligible for redaction based on current criteria.'
        Rails.logger.info("[RedactionDryRun] Found #{total_eligible} request(s) eligible for redaction.")

        # --- Log Details (Optional - Adjust limit as needed) ---
        log_limit = 50 # Log details for up to 50 records
        if total_eligible.positive?
          request_ids = eligible_requests.first(log_limit).map(&:id) # Get IDs after counting/loading

          puts "[RedactionDryRun] Logging IDs for the first #{[total_eligible, log_limit].min} " \
               'eligible requests:'
          puts request_ids.inspect # Print IDs to console
          Rails.logger.info("[RedactionDryRun] Eligible Request IDs (up to #{log_limit}): #{request_ids}")

          eligible_requests.first(log_limit).each do |req|
            log_str = "[RedactionDryRun] Eligible Sample - ID: #{req.id}, Created: #{req.created_at&.iso8601}"
            if req.resolution
              log_str += ", Resolution Type: #{req.resolution.resolving_type}, " \
                         "Resolution Date: #{req.resolution.created_at&.iso8601}"
            end
            Rails.logger.info(log_str)
          end

          if total_eligible > log_limit
            puts "[RedactionDryRun] ... and #{total_eligible - log_limit} more eligible requests not listed."
            Rails.logger.info("[RedactionDryRun] ... and #{total_eligible - log_limit} " \
                              'more eligible requests not listed.')
          end
        end
      rescue NameError => e
        # Handle case where the job class or its dependencies might not be loaded
        error_occurred = true
        puts "[RedactionDryRun] Error: Failed to load necessary classes. #{e.message}"
        Rails.logger.error("[RedactionDryRun] Load Error: #{e.message}\n#{e.backtrace.join("\n")}")
      rescue => e
        # Catch other potential errors during eligibility check
        error_occurred = true
        puts "[RedactionDryRun] An error occurred during the dry run: #{e.message}"
        Rails.logger.error("[RedactionDryRun] Dry Run Error: #{e.message}\n#{e.backtrace.join("\n")}")
      ensure
        if error_occurred
          puts '[RedactionDryRun] Dry run finished with errors.'
          Rails.logger.warn('[RedactionDryRun] Dry run finished with errors.')
        else
          puts '[RedactionDryRun] Dry run observation complete. No data was modified.'
          Rails.logger.info('[RedactionDryRun] Dry run observation complete. No data was modified.')
        end
      end
    end
  end
end
