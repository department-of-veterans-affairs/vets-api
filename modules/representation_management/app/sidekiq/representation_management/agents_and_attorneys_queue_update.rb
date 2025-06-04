# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  class AgentsAndAttorneysQueueUpdate
    include Sidekiq::Job

    # The total number of representatives and organizations parsed from the GCLAWS API
    # must not decrease by more than this percentage from the previous count
    DECREASE_THRESHOLD = 0.20 # 20% maximum decrease allowed
    SLICE_SIZE = 30
    TYPES = RepresentationManagement::GCLAWS::Client::ALLOWED_TYPES

    def perform(force_update_types = [])
      @force_update_types = force_update_types
      @agent_responses = []
      @attorney_responses = []
      @agent_ids = []
      @attorney_ids = []
      @agent_json_for_address_validation = []
      @attorney_json_for_address_validation = []

      save_api_counts
      process_agents
      process_attorneys
      delete_old_accredited_individuals
    rescue => e
      log_error("Error in AgentsAndAttorneysQueueUpdate: #{e.message}")
    end

    private

    def client
      RepresentationManagement::GCLAWS::Client
    end

    def get_counts_from_db
      raise
      # TODO: This needs to fetch the latest count record, not just count records in the db
      {
        agents: AccreditedIndividual.where(individual_type: 'claims_agent').count,
        attorneys: AccreditedIndividual.where(individual_type: 'attorney').count,
        representatives: AccreditedIndividual.where(individual_type: 'representative').count,
        veteran_service_organizations: AccreditedOrganization.count
      }
    end

    def data_transform_for_agent(agent)
      {
        individual_type: 'claims_agent',
        registration_number: agent['number'],
        poa_code: agent['poa'],
        ogc_id: agent['id'],
        first_name: agent['firstName'],
        middle_initial: agent['middleName'].to_s.strip.first,
        last_name: agent['lastName'],
        address_line1: agent['workAddress1'],
        address_line2: agent['workAddress2'],
        address_line3: agent['workAddress3'],
        zip_code: agent['workZip'],
        country_code_iso3: agent['workCountry'],
        country_name: agent['workCountry'],
        phone: agent['workPhoneNumber'],
        email: agent['workEmailAddress'],
        raw_address: raw_address_for_agent(agent)
      }
    end

    def data_transform_for_attorney(attorney)
      {
        individual_type: 'attorney',
        registration_number: attorney['number'],
        poa_code: attorney['poa'],
        ogc_id: attorney['id'],
        first_name: attorney['firstName'],
        middle_initial: attorney['middleName'].to_s.strip.first,
        last_name: attorney['lastName'],
        address_line1: attorney['workAddress1'],
        address_line2: attorney['workAddress2'],
        address_line3: attorney['workAddress3'],
        city: attorney['workCity'],
        state_code: attorney['workState'],
        zip_code: attorney['workZip'],
        phone: attorney['workNumber'],
        email: attorney['emailAddress']
      }
    end

    def delete_old_accredited_individuals
      AccreditedIndividual.where.not(id: @agent_ids + @attorney_ids).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old accredited individual with ID #{record.id}: #{e.message}")
      end
    end

    def get_counts_from_api
      counts = {}
      TYPES.each do |type|
        counts[type] = client.get_accredited_entities(type:, page: 1, page_size: 1).body['totalRecords']
      rescue => e
        log_error("Error fetching count for #{type}: #{e.message}")
      end
      counts
    end

    def current_api_counts
      @current_api_counts ||= get_counts_from_api
    end

    def current_db_counts
      @current_db_counts ||= get_counts_from_db
    end

    def individual_agent_json(record, agent)
      agent_raw_address = raw_address_for_agent(agent)
      {
        id: record.id,
        address_changed:,
        address: {
          address_pou: 'RESIDENCE/CHOICE',
          address_line1: agent_raw_address['address_line1'],
          address_line2: agent_raw_address['address_line2'],
          address_line3: agent_raw_address['address_line3'],
          city: nil,
          zip_code5: agent_raw_address['zip_code']
        }
      }
    end

    def individual_attorney_json(record, attorney)
      attorney_raw_address = raw_address_for_attorney(attorney)
      {
        id: record.id,
        address_changed:,
        address: {
          address_pou: 'RESIDENCE/CHOICE',
          address_line1: attorney_raw_address['address_line1'],
          address_line2: attorney_raw_address['address_line2'],
          address_line3: attorney_raw_address['address_line3'],
          city: attorney_raw_address['city'],
          state: { state_code: attorney_raw_address['state_code'] },
          zip_code5: attorney_raw_address['zip_code']
        }
      }
    end

    def process_agents
      if valid_count?(:agents) || @force_update_types.include?('claims_agent')
        update_agents
        validate_agent_addresses
      else
        log_error("Agents count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
      end
    end

    def process_attorneys
      if valid_count?(:attorneys) || @force_update_types.include?('attorney')
        update_attorneys
        validate_attorney_addresses
      else
        log_error("Attorneys count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
      end
    end

    def raw_address_for_agent(agent)
      {
        address_line1: agent['workAddress1'],
        address_line2: agent['workAddress2'],
        address_line3: agent['workAddress3'],
        zip_code: agent['workZip'],
        work_country: agent['workCountry']
      }.transform_keys(&:to_s)
    end

    def raw_address_for_attorney(attorney)
      {
        address_line1: attorney['workAddress1'],
        address_line2: attorney['workAddress2'],
        address_line3: attorney['workAddress3'],
        city: attorney['workCity'],
        state_code: attorney['workState'],
        zip_code: attorney['workZip']
      }.transform_keys(&:to_s)
    end

    def save_api_counts
      # Do this after fixing the db counts
    end

    def update_agents
      page = 1
      loop do
        response = client.get_accredited_entities(type: 'agents', page:)
        agents = response.body['items']
        break if agents.empty?

        @agent_responses << agents
        agents.each do |agent|
          agent_identifier = { individual_type: 'claims_agent', ogc_id: agent['id'] }
          agent_hash = data_transform_for_agent(agent)
          record = AccreditedIndividual.find_or_create_by(agent_identifier)
          if record.raw_address != raw_address_for_agent(agent)
            @agent_json_for_address_validation << individual_agent_json(record, agent)
          end
          record.update(agent_hash)
          @agent_ids << record.id
        end
        page += 1
      end
    end

    def update_attorneys
      page = 1
      loop do
        response = client.get_accredited_entities(type: 'attorneys', page:)
        attorneys = response.body['items']
        break if attorneys.empty?

        @attorney_responses << attorneys
        attorneys.each do |attorney|
          attorney_identifier = { individual_type: 'attorney', ogc_id: attorney['id'] }
          attorney_hash = data_transform_for_attorney(attorney)
          record = AccreditedIndividual.find_or_create_by(attorney_identifier)
          if record.raw_address != raw_address_for_attorney(attorney)
            @attorney_json_for_address_validation << individual_attorney_json(record, attorney)
          end
          record.update(attorney_hash)
          @attorney_ids << record.id
        end
        page += 1
      end
    end

    def valid_count?(type)
      previous_count = current_db_counts[type]
      new_count = current_api_counts[type]

      # If no previous count exists, allow the update
      return true if previous_count.nil? || previous_count.zero?

      # If new count is greater or equal, allow the update
      return true if new_count >= previous_count

      # Calculate decrease percentage
      decrease_percentage = (previous_count - new_count).to_f / previous_count

      if decrease_percentage > DECREASE_THRESHOLD
        # Log to Slack and don't update
        notify_threshold_exceeded(type, previous_count, new_count, decrease_percentage, DECREASE_THRESHOLD)
        false
      else
        true
      end
    end

    def validate_addresses(records_for_validation,
                           description = 'Batching address updates from GCLAWS Accreditation API')
      return if records_for_validation.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = description

      begin
        batch.jobs do
          records_for_validation.each_slice(SLICE_SIZE) do |individuals|
            json_individuals = individuals.to_json
            RepresentationManagement::AccreditedIndividualsUpdate.perform_in(delay.minutes, json_individuals)
            delay += 1
          end
        end
      rescue => e
        log_error("Error queuing address updates: #{e.message}")
      end
    end

    def validate_agent_addresses
      validate_addresses(
        @agent_json_for_address_validation, 'Batching agent address updates from GCLAWS Accreditation API'
      )
    end

    def validate_attorney_addresses
      validate_addresses(
        @attorney_json_for_address_validation, 'Batching attorney address updates from GCLAWS Accreditation API'
      )
    end

    def log_error(message)
      Rails.logger.error("RepresentationManagement::AgentsAndAttorneysQueueUpdate error: #{message}")
    end
  end
end
