# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  class AgentsAndAttorneysQueueUpdate
    include Sidekiq::Job

    SLICE_SIZE = 30

    def perform
      @agent_responses = []
      @attorney_responses = []
      @agent_ids = []
      @attorney_ids = []
      @agent_json_for_address_validation = []
      @attorney_json_for_address_validation = []

      update_agents
      update_attorneys
      validate_agent_addresses
      validate_attorney_addresses
      delete_old_accredited_individuals
    rescue => e
      log_error("Error in AgentsAndAttorneysQueueUpdate: #{e.message}")
    end

    private

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

    def update_agents
      page = 1
      loop do
        response = RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'agents', page:)
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
        response = RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'attorneys', page:)
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
