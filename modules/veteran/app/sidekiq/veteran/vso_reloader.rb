# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Veteran
  class RepReloader < BaseReloader
    include Sidekiq::Job
    include SentryLogging

    def perform
      array_of_organizations = reload_representatives

      # This Where Not statement is for removing anyone no longer on the lists pulled down from OGC
      Veteran::Service::Representative.where.not(representative_id: array_of_organizations).find_each do |rep|
        # These are test users that Sandbox requires.  Don't delete them.
        next if rep.first_name == 'Tamara' && rep.last_name == 'Ellis'
        next if rep.first_name == 'John' && rep.last_name == 'Doe'

        rep.destroy!
      end
    rescue Faraday::ConnectionFailed => e
      log_message_to_sentry("OGC connection failed: #{e.message}", :warn)
      log_to_slack('Rep Reloader failed to connect to OGC')
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("Rep Reloading error: #{e.message}", :warn)
      log_to_slack('Rep Reloader job has failed!')
    end

    def reload_attorneys
      fetch_data('attorneyexcellist.asp').map do |attorney|
        find_or_create_attorneys(attorney) if attorney['Registration Num'].present?

        attorney['Registration Num']
      end
    end

    def reload_claim_agents
      fetch_data('caexcellist.asp').map do |claim_agent|
        find_or_create_claim_agents(claim_agent) if claim_agent['Registration Num'].present?
        claim_agent['Registration Num']
      end
    end

    private

    def reload_representatives
      reload_attorneys + reload_claim_agents
    end

    def find_or_create_attorneys(attorney)
      rep = find_or_initialize(attorney)
      rep.user_types << 'attorney' unless rep.user_types.include?('attorney')
      rep.save
    end

    def find_or_create_claim_agents(claim_agent)
      rep = find_or_initialize(claim_agent)
      rep.user_types << 'claim_agents' unless rep.user_types.include?('claim_agents')
      rep.save
    end

    def log_to_slack(message)
      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#api-benefits-claims',
                                       username: 'RepReloader')
      client.notify(message)
    end
  end
end
