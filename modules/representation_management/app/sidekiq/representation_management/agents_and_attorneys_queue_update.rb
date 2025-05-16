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
      page = 1

      loop do
        response = RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'agents', page:)
        agents = response.body['items']
        break if agents.empty?

        agent_responses << agents
        agents.each do |agent|
          # This needs expanded to include the type of AccreditedIndividual and all the correct fields
          # that are needed to create the record.
          record = AccreditedIndividual.find_or_create_by(agent)
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
          record = AccreditedIndividual.find_or_create_by(attorney)
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

    def log_error(message)
      Rails.logger.error("SendExpiredEmailJob error: #{message}")
    end
  end
end
