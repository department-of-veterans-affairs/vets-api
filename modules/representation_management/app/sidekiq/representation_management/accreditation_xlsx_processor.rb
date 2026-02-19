# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  # Processes GCLAWS SSRS XLSX file data for accredited entities.
  # Downloads the XLSX file once, parses it for all requested entity types,
  # directly writes email/phone/name/raw_address updates to the database,
  # and queues address validation jobs (by ID) for records with address changes.
  #
  # This is a third data pipeline alongside:
  # - AccreditedEntitiesQueueUpdates (GCLAWS REST API)
  # - VSOReloader (OGC ASP endpoints)
  class AccreditationXlsxProcessor
    include Sidekiq::Job

    VALID_TYPES = %w[attorney claims_agent representative organization].freeze
    INDIVIDUAL_TYPES = %w[attorney claims_agent representative].freeze
    SLICE_SIZE = 30

    # @param types [Array<String>] Entity types to process (defaults to all)
    def perform(types = VALID_TYPES)
      @report = []
      @start_time = Time.current
      @types = validate_types(types)

      log_info("Starting AccreditationXlsxProcessor for types: #{@types.join(', ')}")

      # Step 1: Ensure records exist via VSOReloader
      reload_entities

      # Step 2: Download and process XLSX file
      download_and_process_xlsx

      finalize_report
    rescue ArgumentError
      raise
    rescue => e
      log_error("AccreditationXlsxProcessor failed: #{e.message}")
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

      individual_ids, organization_ids = apply_updates_and_collect_ids(parsed_data)

      queue_individual_updates(individual_ids)
      queue_organization_updates(organization_ids)
    end

    # Applies direct DB writes for contact/name fields and collects IDs needing address validation.
    # @param parsed_data [Hash] Parsed XLSX data keyed by entity type
    # @return [Array<Array<String>, Array<String>>] Individual and organization IDs needing address validation
    def apply_updates_and_collect_ids(parsed_data)
      individual_ids = []
      organization_ids = []

      parsed_data.each do |type, records|
        @report << "XLSX Parsed: #{type} - #{records.size} rows"

        if INDIVIDUAL_TYPES.include?(type)
          individual_ids.concat(update_individuals(type, records))
        elsif type == 'organization'
          organization_ids.concat(update_organizations(records))
        end
      end

      [individual_ids, organization_ids]
    end

    # Writes contact field updates directly to AccreditedIndividual records and
    # returns IDs of records whose addresses changed (needing validation).
    # @param type [String] The individual type
    # @param xlsx_records [Array<Hash>] Parsed XLSX records
    # @return [Array<String>] IDs of records needing address validation
    def update_individuals(type, xlsx_records)
      ids_needing_validation = []
      records_updated = 0

      xlsx_records.each do |xlsx_record|
        registration_number = xlsx_record[:registration_number]
        next if registration_number.blank?

        record = AccreditedIndividual.find_by(registration_number:, individual_type: type)
        next unless record

        address_changed = apply_individual_updates(record, xlsx_record)
        next if address_changed.nil?

        records_updated += 1
        ids_needing_validation << record.id if address_changed
      end

      log_update_report(type, records_updated, ids_needing_validation.size)
      ids_needing_validation
    end

    # Applies contact field updates to an individual record.
    # @return [Boolean, nil] true if address changed, false if only contact changed, nil if no changes
    def apply_individual_updates(record, xlsx_record)
      raw_address = xlsx_record[:raw_address]
      email = xlsx_record[:email]
      phone = xlsx_record[:phone_number]

      address_changed = raw_address.present? && record.raw_address != raw_address
      email_changed = email.present? && record.email != email
      phone_changed = phone.present? && record.phone != phone

      return nil unless address_changed || email_changed || phone_changed

      updates = {}
      updates[:email] = email if email_changed
      updates[:phone] = phone if phone_changed
      updates[:raw_address] = raw_address if address_changed

      record.update(updates)
      address_changed
    end

    # Writes contact/name field updates directly to AccreditedOrganization records and
    # returns IDs of records whose addresses changed (needing validation).
    # @param xlsx_records [Array<Hash>] Parsed XLSX records
    # @return [Array<String>] IDs of records needing address validation
    def update_organizations(xlsx_records)
      ids_needing_validation = []
      records_updated = 0

      xlsx_records.each do |xlsx_record|
        poa_code = xlsx_record[:poa_code]
        next if poa_code.blank?

        record = AccreditedOrganization.find_by(poa_code:)
        next unless record

        address_changed = apply_organization_updates(record, xlsx_record)
        next if address_changed.nil?

        records_updated += 1
        ids_needing_validation << record.id if address_changed
      end

      log_update_report('organization', records_updated, ids_needing_validation.size)
      ids_needing_validation
    end

    # Applies contact/name field updates to an organization record.
    # @return [Boolean, nil] true if address changed, false if only contact changed, nil if no changes
    def apply_organization_updates(record, xlsx_record)
      raw_address = xlsx_record[:raw_address]
      phone = xlsx_record[:phone]

      address_changed = raw_address.present? && record.raw_address != raw_address
      phone_changed = phone.present? && record.phone != phone

      return nil unless address_changed || phone_changed

      updates = {}
      updates[:phone] = phone if phone_changed
      updates[:raw_address] = raw_address if address_changed

      record.update(updates)
      address_changed
    end

    def log_update_report(type, records_updated, validation_count)
      @report << "#{type}: #{records_updated} updated, " \
                 "#{validation_count} needing address validation"
    end

    # Queues individual address validation jobs in batches with incremental delays.
    # @param ids [Array<String>] AccreditedIndividual IDs needing address validation
    def queue_individual_updates(ids)
      return if ids.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = 'Batching individual address validation from XLSX'

      begin
        batch.jobs do
          ids.each_slice(SLICE_SIZE) do |slice|
            AccreditedIndividualsUpdate.perform_in(delay.minutes, slice)
            delay += 1
          end
        end

        slices_count = (ids.size.to_f / SLICE_SIZE).ceil
        @report << "Individual address validation: #{ids.size} records in #{slices_count} batches"
      rescue => e
        log_error("Error queuing individual updates: #{e.message}")
      end
    end

    # Queues organization address validation jobs in batches with incremental delays.
    # @param ids [Array<String>] AccreditedOrganization IDs needing address validation
    def queue_organization_updates(ids)
      return if ids.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = 'Batching organization address validation from XLSX'

      begin
        batch.jobs do
          ids.each_slice(SLICE_SIZE) do |slice|
            AccreditedOrganizationsUpdate.perform_in(delay.minutes, slice)
            delay += 1
          end
        end

        slices_count = (ids.size.to_f / SLICE_SIZE).ceil
        @report << "Organization address validation: #{ids.size} records in #{slices_count} batches"
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

      report_text = "RepresentationManagement::AccreditationXlsxProcessor Report\n" \
                    "#{@report.join("\n")}"

      log_info(report_text)
      log_to_slack(report_text)
    end

    def log_info(message)
      Rails.logger.info("RepresentationManagement::AccreditationXlsxProcessor: #{message}")
    end

    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditationXlsxProcessor: #{message}")
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'RepresentationManagement::AccreditationXlsxProcessor Bot')
      client.notify(message)
    end
  end
end
