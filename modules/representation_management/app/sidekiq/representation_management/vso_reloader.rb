# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'

module RepresentationManagement
  class VSOReloader < BaseReloader
    include Sidekiq::Job
    include Vets::SharedLogging

    # The total number of representatives and organizations parsed from the ingested .ASP files
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed

    def perform
      setup_ingestion
      array_of_organizations = reload_representatives
      save_accreditation_totals
      remove_obsolete_representatives(array_of_organizations)
      complete_ingestion_log
    rescue Faraday::ConnectionFailed => e
      handle_connection_failure(e)
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      handle_client_error(e)
    end

    # Reloads attorney data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_attorneys
      reload_representative_type(
        endpoint: 'attorneyexcellist.asp',
        rep_type: :attorneys,
        individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_ATTORNEY,
        processor: method(:find_or_create_attorneys)
      )
    end

    # Reloads claim agent data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_claim_agents
      reload_representative_type(
        endpoint: 'caexcellist.asp',
        rep_type: :claims_agents,
        individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_CLAIM_AGENT,
        processor: method(:find_or_create_claim_agents)
      )
    end

    # Reloads VSO representative and organization data from OGC
    # @return [Array<String>] Array of representative IDs that should remain in the system
    #   Used by perform method to determine which representatives to keep vs delete
    def reload_vso_reps
      mark_vso_entities_running
      ensure_initial_counts
      vso_data = fetch_data('orgsexcellist.asp')
      counts = calculate_vso_counts(vso_data)

      # Validate both counts - if either fails, skip processing both to maintain data integrity
      reps_valid = valid_count?(:vso_representatives, counts[:reps])
      orgs_valid = valid_count?(:vso_organizations, counts[:orgs])

      if reps_valid && orgs_valid
        process_valid_vso_data(vso_data, counts)
      else
        handle_vso_validation_failure(reps_valid, orgs_valid, counts)
      end
    rescue => e
      mark_vso_entities_failed(e.message)
      raise
    end

    # Common method for reloading attorney and claim agent data
    # @param endpoint [String] OGC endpoint to fetch data from
    # @param rep_type [Symbol] Type of representative for validation (:attorneys, :claims_agents)
    # @param individual_type [String] Database user type constant
    # @param processor [Method] Method to process each record
    # @return [Array<String>] Representative IDs - either newly processed IDs or existing IDs if validation fails
    def reload_representative_type(endpoint:, rep_type:, individual_type:, processor:)
      entity_type = map_rep_type_to_entity_type(rep_type)
      @ingestion_log&.mark_entity_running!(entity_type)
      ensure_initial_counts

      data = fetch_data(endpoint)
      new_count = data.count { |record| normalized_registration_number(record).present? }

      if valid_count?(rep_type, new_count)
        process_valid_representative_data(data, processor, entity_type, new_count)
      else
        handle_representative_validation_failure(entity_type, rep_type, individual_type, new_count)
      end
    rescue => e
      @ingestion_log&.mark_entity_failed!(entity_type, error: e.message)
      raise
    end

    private

    # Setup methods for perform

    def setup_ingestion
      @ingestion_log = RepresentationManagement::AccreditationDataIngestionLog.start_ingestion!(
        dataset: :trexler_file
      )
      @initial_counts = fetch_initial_counts
      @validation_results = {}
    end

    def remove_obsolete_representatives(array_of_organizations)
      AccreditedIndividual.where.not(registration_number: array_of_organizations).find_each do |rep|
        next if test_user?(rep)

        rep.destroy!
      end
    end

    def test_user?(rep)
      (rep.first_name == 'Tamara' && rep.last_name == 'Ellis') ||
        (rep.first_name == 'John' && rep.last_name == 'Doe')
    end

    def handle_connection_failure(error)
      log_message_to_sentry("OGC connection failed: #{error.message}", :warn)
      log_to_slack('VSO Reloader failed to connect to OGC')
      fail_ingestion_log("OGC connection failed: #{error.message}")
    end

    def handle_client_error(error)
      log_message_to_sentry("VSO Reloading error: #{error.message}", :warn)
      log_to_slack('VSO Reloader job has failed!')
      fail_ingestion_log("VSO Reloading error: #{error.message}")
    end

    # VSO-specific helper methods

    def mark_vso_entities_running
      @ingestion_log&.mark_entity_running!(:representatives)
      @ingestion_log&.mark_entity_running!(:veteran_service_organizations)
    end

    def mark_vso_entities_failed(error_message)
      @ingestion_log&.mark_entity_failed!(:representatives, error: error_message)
      @ingestion_log&.mark_entity_failed!(:veteran_service_organizations, error: error_message)
    end

    def process_valid_vso_data(vso_data, counts)
      result = process_vso_data(vso_data)
      @ingestion_log&.mark_entity_success!(:representatives, count: counts[:reps])
      @ingestion_log&.mark_entity_success!(:veteran_service_organizations, count: counts[:orgs])
      result
    end

    def handle_vso_validation_failure(reps_valid, orgs_valid, counts)
      mark_representatives_failed(counts) unless reps_valid
      mark_organizations_failed(counts) unless orgs_valid
      existing_vso_registration_numbers
    end

    def mark_representatives_failed(counts)
      @ingestion_log&.mark_entity_failed!(
        :representatives,
        error: 'Count validation failed',
        count: counts[:reps],
        previous_count: get_previous_count(:vso_representatives)
      )
    end

    def mark_organizations_failed(counts)
      @ingestion_log&.mark_entity_failed!(
        :veteran_service_organizations,
        error: 'Count validation failed',
        count: counts[:orgs],
        previous_count: get_previous_count(:vso_organizations)
      )
    end

    def existing_vso_registration_numbers
      AccreditedIndividual
        .where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE)
        .pluck(:registration_number)
    end

    # Representative type helper methods

    def normalized_registration_number(record)
      record['Registration Num']&.strip
    end

    def process_valid_representative_data(data, processor, entity_type, new_count)
      result = data.filter_map do |record|
        registration_number = normalized_registration_number(record)
        next if registration_number.blank?

        processor.call(record)
        registration_number
      end
      @ingestion_log&.mark_entity_success!(entity_type, count: new_count)
      result
    end

    def handle_representative_validation_failure(entity_type, rep_type, individual_type, new_count)
      @ingestion_log&.mark_entity_failed!(
        entity_type,
        error: 'Count validation failed',
        count: new_count,
        previous_count: get_previous_count(rep_type)
      )
      AccreditedIndividual.where(individual_type:).pluck(:registration_number)
    end

    # Combines all representative IDs from attorneys, claim agents, and VSOs
    # @return [Array<String>] Combined array of all representative IDs that should remain in the system
    #   This list is used to identify representatives that are no longer in OGC data and should be removed
    def reload_representatives
      reload_attorneys + reload_claim_agents + reload_vso_reps
    end

    def find_or_create_attorneys(attorney)
      rep = find_or_initialize_by_id(attorney, AccreditedIndividual::INDIVIDUAL_TYPE_ATTORNEY)
      rep.save
    end

    def find_or_create_claim_agents(claim_agent)
      rep = find_or_initialize_by_id(claim_agent, AccreditedIndividual::INDIVIDUAL_TYPE_CLAIM_AGENT)
      rep.save
    end

    def find_or_create_vso(vso)
      unless vso['Representative']&.match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/)
        ClaimsApi::Logger.log('VSO', detail: "Rep name not in expected format: #{vso['Registration Num']}")
        return
      end

      rep = find_or_initialize_by_id(convert_vso_to_useable_hash(vso), AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE)
      rep.save
    end

    def convert_vso_to_useable_hash(vso)
      last_name, first_name, middle_initial = vso['Representative'].match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/).captures # rubocop:disable Layout/LineLength

      {
        'Last Name' => last_name,
        'First Name' => first_name,
        'Middle Initial' => middle_initial || '',
        'Registration Num' => vso['Registration Num'],
        'POA Code' => vso['POA'],
        'Phone' => vso['Rep Phone'] || vso['Org Phone'],
        'City' => vso['Rep City'] || vso['Org City'],
        'State' => vso['Rep State'] || vso['Org State'],
        'Zip' => vso['Rep Zip'],
        'AccrRepresentativeId' => vso['AccrRepresentativeId']
      }
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'VSOReloader')
      client.notify(message)
    end

    def fetch_initial_counts
      {
        attorneys: AccreditedIndividual.where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_ATTORNEY).count,
        claims_agents: AccreditedIndividual.where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_CLAIM_AGENT).count,
        vso_representatives: AccreditedIndividual
          .where(individual_type: AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE).count,
        vso_organizations: AccreditedOrganization.count
      }
    end

    def ensure_initial_counts
      @initial_counts ||= fetch_initial_counts
      @validation_results ||= {}
    end

    def valid_count?(rep_type, new_count)
      previous_count = get_previous_count(rep_type)

      # If no previous count exists, allow the update
      return true if previous_count.nil? || previous_count.zero?

      # If new count is greater or equal, allow the update
      return true if new_count >= previous_count

      # Calculate decrease percentage
      decrease_percentage = (previous_count - new_count).to_f / previous_count

      if decrease_percentage > DECREASE_THRESHOLD
        # Log to Slack and don't update
        notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, DECREASE_THRESHOLD)
        @validation_results[rep_type] = nil
        false
      else
        @validation_results[rep_type] = new_count
        true
      end
    end

    def get_previous_count(rep_type)
      # Get the most recent count from the database
      latest_total = RepresentationManagement::AccreditationTotal.order(created_at: :desc).first

      # If we have a previous count in the database, use it
      # Otherwise, use the current count from the database
      latest_total&.send(rep_type) || @initial_counts[rep_type]
    end

    def notify_threshold_exceeded(rep_type, previous_count, new_count, decrease_percentage, threshold)
      message = "⚠️ VSO Reloader Alert: #{rep_type.to_s.humanize} count decreased beyond threshold!\n" \
                "Previous: #{previous_count}\n" \
                "New: #{new_count}\n" \
                "Decrease: #{(decrease_percentage * 100).round(2)}%\n" \
                "Threshold: #{(threshold * 100).round(2)}%\n" \
                'Action: Update skipped, manual review required'

      log_to_slack(message)
      log_message_to_sentry("VSO Reloader threshold exceeded for #{rep_type}", :warn,
                            previous_count:,
                            new_count:,
                            decrease_percentage:)
    end

    def save_accreditation_totals
      # For manual reprocessing, some types may not be in @validation_results
      # If a type wasn't processed, use the current count from the database
      # If a type was processed and failed validation, it will be nil
      RepresentationManagement::AccreditationTotal.create!(
        attorneys: get_count_for_save(:attorneys),
        claims_agents: get_count_for_save(:claims_agents),
        vso_representatives: get_count_for_save(:vso_representatives),
        vso_organizations: get_count_for_save(:vso_organizations)
      )
    end

    def get_count_for_save(rep_type)
      # If the type was processed (exists in validation_results), use that value (even if nil)
      # Otherwise, use the current count from the database
      @validation_results.key?(rep_type) ? @validation_results[rep_type] : @initial_counts[rep_type]
    end

    def calculate_vso_counts(vso_data)
      {
        reps: vso_data.count { |v| v['Representative'].present? && v['Registration Num']&.strip.present? },
        orgs: vso_data.map { |v| v['POA'] }.compact.uniq.count
      }
    end

    def process_vso_data(vso_data) # rubocop:disable Metrics/MethodLength
      vso_reps = []

      vso_orgs = vso_data.map do |vso_rep|
        next unless vso_rep['Representative']

        registration_number = vso_rep['Registration Num']&.strip
        next if registration_number.blank?

        find_or_create_vso(vso_rep)
        vso_reps << registration_number
        {
          poa_code: vso_rep['POA'].gsub(/\W/, ''),
          name: vso_rep['Organization Name'],
          phone: vso_rep['Org Phone'],
          state_code: vso_rep['Org State']
        }
      end.compact.uniq

      current_poa_codes = vso_orgs.map { |org| org[:poa_code] }.compact_blank.uniq

      existing_ogc_ids_by_poa = AccreditedOrganization
                                .where(poa_code: current_poa_codes)
                                .pluck(:poa_code, :ogc_id)
                                .to_h

      vso_orgs.each { |org| org[:ogc_id] = existing_ogc_ids_by_poa[org[:poa_code]] || AccreditedIndividual::DUMMY_OGC_ID }

      AccreditedOrganization.import(
        vso_orgs,
        on_duplicate_key_update: {
          conflict_target: [:poa_code],
          columns: %i[name phone state_code]
        }
      )

      AccreditedOrganization.where.not(poa_code: current_poa_codes).destroy_all

      vso_reps
    end

    # Maps VSOReloader's rep_type symbols to AccreditationDataIngestionLog entity types
    #
    # @param rep_type [Symbol] The rep_type used in VSOReloader (:attorneys, :claims_agents, etc.)
    # @return [String] The entity type for the log model
    def map_rep_type_to_entity_type(rep_type)
      case rep_type
      when :attorneys then 'attorneys'
      when :claims_agents then 'agents'
      when :vso_representatives then 'representatives'
      when :vso_organizations then 'veteran_service_organizations'
      else rep_type.to_s
      end
    end

    # Completes the ingestion log with overall metrics
    def complete_ingestion_log
      return unless @ingestion_log

      @ingestion_log.complete_ingestion!(
        attorneys: @validation_results[:attorneys] || @initial_counts[:attorneys],
        claims_agents: @validation_results[:claims_agents] || @initial_counts[:claims_agents],
        vso_representatives: @validation_results[:vso_representatives] || @initial_counts[:vso_representatives],
        vso_organizations: @validation_results[:vso_organizations] || @initial_counts[:vso_organizations]
      )
    end

    # Marks the ingestion log as failed
    #
    # @param error_message [String] The error message to log
    def fail_ingestion_log(error_message)
      return unless @ingestion_log

      @ingestion_log.fail_ingestion!(error: error_message)
    end
  end
end
