# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  # Main orchestrator for XLSX-based address/contact updates for accredited entities.
  # Downloads the GCLAWS SSRS XLSX file once, parses it for all requested entity types,
  # computes diffs against existing records, and queues update jobs in batches.
  #
  # This is a third data pipeline alongside:
  # - AccreditedEntitiesQueueUpdates (GCLAWS REST API)
  # - VSOReloader (OGC ASP endpoints)
  class AccreditationQueueUpdates
    include Sidekiq::Job

    VALID_TYPES = %w[attorney claims_agent representative organization].freeze
    INDIVIDUAL_TYPES = %w[attorney claims_agent representative].freeze
    SLICE_SIZE = 30

    # @param types [Array<String>] Entity types to process (defaults to all)
    def perform(types = VALID_TYPES)
      @report = []
      @start_time = Time.current
      @types = validate_types(types)

      log_info("Starting AccreditationQueueUpdates for types: #{@types.join(', ')}")

      # Step 1: Ensure records exist via VSOReloader
      reload_entities

      # Step 2: Download and process XLSX file
      download_and_process_xlsx

      finalize_report
    rescue ArgumentError
      raise
    rescue => e
      log_error("AccreditationQueueUpdates failed: #{e.message}")
      @report << "ERROR: #{e.message}"
      finalize_report
    end

    private

    # Validates and normalizes the types parameter
    # @param types [Array<String>] The types to validate
    # @return [Array<String>] Validated types
    def validate_types(types)
      types = Array(types)
      invalid = types - VALID_TYPES
      log_error("Invalid types ignored: #{invalid.join(', ')}") if invalid.any?

      valid = types & VALID_TYPES
      raise ArgumentError, 'No valid entity types provided' if valid.empty?

      valid
    end

    # Calls VSOReloader synchronously to ensure records exist before XLSX address updates
    def reload_entities
      log_info('Running VSOReloader to ensure records exist...')
      VSOReloader.new.perform(@types)
      log_info('VSOReloader complete')
      @report << 'VSOReloader: Complete'
    rescue => e
      log_error("VSOReloader failed: #{e.message}")
      @report << "VSOReloader: FAILED - #{e.message}"
      raise
    end

    # Downloads the XLSX file and processes it
    def download_and_process_xlsx
      GCLAWS::XlsxClient.download_accreditation_xlsx do |result|
        if result[:success]
          process_xlsx_file(result[:file_path])
        else
          handle_download_failure(result)
        end
      end
    end

    # Processes the downloaded XLSX file
    # @param file_path [String] Path to the downloaded XLSX file
    def process_xlsx_file(file_path)
      file_content = File.binread(file_path)
      parsed_data = XlsxFileProcessor.new(file_content, @types).process

      if parsed_data.empty?
        log_error('XLSX file parsing returned no data')
        @report << 'XLSX Parsing: No data returned'
        return
      end

      individual_updates, organization_updates = compute_all_diffs(parsed_data)

      queue_individual_updates(individual_updates)
      queue_organization_updates(organization_updates)
    end

    # Computes diffs for all entity types from parsed XLSX data
    # @param parsed_data [Hash] Parsed XLSX data keyed by entity type
    # @return [Array<Array<Hash>, Array<Hash>>] Individual and organization updates
    def compute_all_diffs(parsed_data)
      individual_updates = []
      organization_updates = []

      parsed_data.each do |type, records|
        @report << "XLSX Parsed: #{type} - #{records.size} rows"

        if INDIVIDUAL_TYPES.include?(type)
          individual_updates.concat(compute_individual_diffs(type, records))
        elsif type == 'organization'
          organization_updates.concat(compute_organization_diffs(records))
        end
      end

      [individual_updates, organization_updates]
    end

    # Computes diffs for individual entities (attorneys, claims agents, representatives)
    # @param type [String] The individual type
    # @param xlsx_records [Array<Hash>] Parsed XLSX records
    # @return [Array<Hash>] Records with changes to apply
    def compute_individual_diffs(type, xlsx_records)
      updates = []

      xlsx_records.each do |xlsx_record|
        registration_number = xlsx_record[:registration_number]
        next if registration_number.blank?

        record = AccreditedIndividual.find_by(
          registration_number:,
          individual_type: type
        )
        next unless record

        diff = build_individual_diff(record, xlsx_record)
        updates << diff if diff
      end

      @report << "#{type}: #{updates.size} records with changes"
      updates
    end

    # Builds a diff hash for an individual record
    # @param record [AccreditedIndividual] Existing database record
    # @param xlsx_record [Hash] Parsed XLSX data
    # @return [Hash, nil] Update payload or nil if no changes
    def build_individual_diff(record, xlsx_record)
      raw_address = xlsx_record[:raw_address]
      email = xlsx_record[:email]
      phone = xlsx_record[:phone_number]

      address_changed = raw_address.present? && record.raw_address != raw_address
      email_changed = email.present? && record.email != email
      phone_changed = phone.present? && record.phone != phone

      return nil unless address_changed || email_changed || phone_changed

      {
        'id' => record.id,
        'email' => email,
        'phone' => phone,
        'raw_address' => raw_address,
        'address_changed' => address_changed,
        'email_changed' => email_changed,
        'phone_changed' => phone_changed
      }
    end

    # Computes diffs for organization entities
    # @param xlsx_records [Array<Hash>] Parsed XLSX records
    # @return [Array<Hash>] Records with changes to apply
    def compute_organization_diffs(xlsx_records)
      updates = []

      xlsx_records.each do |xlsx_record|
        poa_code = xlsx_record[:poa_code]
        next if poa_code.blank?

        record = AccreditedOrganization.find_by(poa_code:)
        next unless record

        diff = build_organization_diff(record, xlsx_record)
        updates << diff if diff
      end

      @report << "organization: #{updates.size} records with changes"
      updates
    end

    # Builds a diff hash for an organization record
    # @param record [AccreditedOrganization] Existing database record
    # @param xlsx_record [Hash] Parsed XLSX data
    # @return [Hash, nil] Update payload or nil if no changes
    def build_organization_diff(record, xlsx_record)
      raw_address = xlsx_record[:raw_address]
      name = xlsx_record[:name]
      phone = xlsx_record[:phone]

      address_changed = raw_address.present? && record.raw_address != raw_address
      name_changed = name.present? && record.name != name
      phone_changed = phone.present? && record.phone != phone

      return nil unless address_changed || name_changed || phone_changed

      {
        'id' => record.id,
        'name' => name,
        'phone' => phone,
        'raw_address' => raw_address,
        'address_changed' => address_changed,
        'name_changed' => name_changed,
        'phone_changed' => phone_changed
      }
    end

    # Queues individual update jobs in batches with incremental delays
    # @param updates [Array<Hash>] Individual update payloads
    def queue_individual_updates(updates)
      return if updates.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = 'Batching individual address/contact updates from XLSX'

      begin
        batch.jobs do
          updates.each_slice(SLICE_SIZE) do |slice|
            AccreditedIndividualsUpdate.perform_in(delay.minutes, slice.to_json)
            delay += 1
          end
        end

        slices_count = (updates.size.to_f / SLICE_SIZE).ceil
        @report << "Individual updates: #{updates.size} records in #{slices_count} batches"
      rescue => e
        log_error("Error queuing individual updates: #{e.message}")
      end
    end

    # Queues organization update jobs in batches with incremental delays
    # @param updates [Array<Hash>] Organization update payloads
    def queue_organization_updates(updates)
      return if updates.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = 'Batching organization address/contact updates from XLSX'

      begin
        batch.jobs do
          updates.each_slice(SLICE_SIZE) do |slice|
            AccreditedOrganizationsUpdate.perform_in(delay.minutes, slice.to_json)
            delay += 1
          end
        end

        slices_count = (updates.size.to_f / SLICE_SIZE).ceil
        @report << "Organization updates: #{updates.size} records in #{slices_count} batches"
      rescue => e
        log_error("Error queuing organization updates: #{e.message}")
      end
    end

    # Handles XLSX download failure
    # @param result [Hash] Error result from XlsxClient
    def handle_download_failure(result)
      error_msg = "XLSX download failed: #{result[:error]} (status: #{result[:status]})"
      log_error(error_msg)
      @report << "XLSX Download: FAILED - #{result[:error]}"
    end

    # Finalizes and sends the report to Slack
    def finalize_report
      duration = Time.current - @start_time
      @report << "\nDuration: #{duration.round(2)}s"

      report_text = "RepresentationManagement::AccreditationQueueUpdates Report\n" \
                    "#{@report.join("\n")}"

      log_info(report_text)
      log_to_slack(report_text)
    end

    def log_info(message)
      Rails.logger.info("RepresentationManagement::AccreditationQueueUpdates: #{message}")
    end

    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditationQueueUpdates: #{message}")
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'RepresentationManagement::AccreditationQueueUpdates Bot')
      client.notify(message)
    end
  end
end
