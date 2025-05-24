# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  class AgentsAndAttorneysQueueUpdate
    include Sidekiq::Job

    def perform
      agent_responses = []
      attorney_responses = []
      agent_ids = []
      attorney_ids = []
      agent_ids_for_address_validation = []
      attorney_ids_for_address_validation = []
      page = 1

      loop do
        response = RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'agents', page:)
        agents = response.body['items']
        break if agents.empty?

        agent_responses << agents
        agents.each do |agent|
          agent_identifier = { individual_type: 'claims_agent', ogc_id: agent['id'] }
          agent_hash = data_transform_for_agent(agent)
          record = AccreditedIndividual.find_or_create_by(agent_identifier)
          agent_ids_for_address_validation << record.id if record.raw_address != raw_address_for_agent(agent)
          record.update(agent_hash)
          agent_ids << record.id
        end
        page += 1
      end

      page = 1
      loop do
        response = RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'attorneys', page:)
        attorneys = response.body['items']
        break if attorneys.empty?

        attorney_responses << attorneys
        attorneys.each do |attorney|
          attorney_identifier = { individual_type: 'attorney', ogc_id: attorney['id'] }
          attorney_hash = data_transform_for_attorney(attorney)
          record = AccreditedIndividual.find_or_create_by(attorney_identifier)
          attorney_ids << record.id
        end
        page += 1
      end

      AccreditedIndividual.where(type: 'agent').where.not(id: agent_ids).find_each do |agent|
        agent.update(deactivated_at: Time.zone.now)
      end
      AccreditedIndividual.where(type: 'attorney').where.not(id: attorney_ids).find_each do |attorney|
        attorney.update(deactivated_at: Time.zone.now)
      end
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

    def raw_address_for_agent(agent)
      {
        address_line1: agent['workAddress1'],
        address_line2: agent['workAddress2'],
        address_line3: agent['workAddress3'],
        zip_code: agent['workZip'],
        work_country: agent['workCountry']
      }
    end

    def raw_address_for_attorney(attorney)
      {
        address_line1: attorney['workAddress1'],
        address_line2: attorney['workAddress2'],
        address_line3: attorney['workAddress3'],
        city: attorney['workCity'],
        state_code: attorney['workState'],
        zip_code: attorney['workZip']
      }
    end

    def log_error(message)
      Rails.logger.error("SendExpiredEmailJob error: #{message}")
    end
  end
end
