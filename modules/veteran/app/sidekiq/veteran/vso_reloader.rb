# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Veteran
  class VSOReloader < BaseReloader
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
      log_to_slack('VSO Reloader failed to connect to OGC')
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_message_to_sentry("VSO Reloading error: #{e.message}", :warn)
      log_to_slack('VSO Reloader job has failed!')
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

    def reload_vso_reps
      vso_reps = []
      vso_orgs = fetch_data('orgsexcellist.asp').map do |vso_rep|
        next unless vso_rep['Representative']

        find_or_create_vso(vso_rep) if vso_rep['Registration Num'].present?
        vso_reps << vso_rep['Registration Num']
        {
          poa: vso_rep['POA'].gsub(/\W/, ''),
          name: vso_rep['Organization Name'],
          phone: vso_rep['Org Phone'],
          state: vso_rep['Org State']
        }
      end.compact.uniq
      Veteran::Service::Organization.import(vso_orgs, on_duplicate_key_update: %i[name phone state])

      vso_reps
    end

    private

    def reload_representatives
      reload_attorneys + reload_claim_agents + reload_vso_reps
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

    def find_or_create_vso(vso)
      unless vso['Representative'].match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/)
        ClaimsApi::Logger.log('VSO',
                              detail: "Rep name not in expected format: #{vso['Registration Num']}")
        return
      end

      last_name, first_name, middle_initial = vso['Representative']
                                              .match(/(.*?), (.*?)(?: (.{0,1})[a-zA-Z]*)?$/).captures

      last_name = last_name.strip

      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: vso['Registration Num'],
                                                                   first_name:,
                                                                   last_name:)
      poa_code = vso['POA'].gsub(/\W/, '')
      rep.poa_codes << poa_code unless rep.poa_codes.include?(poa_code)

      rep.phone = vso['Org Phone']
      rep.user_types << 'veteran_service_officer' unless rep.user_types.include?('veteran_service_officer')
      rep.middle_initial = middle_initial.presence || ''
      rep.save
    end

    def log_to_slack(message)
      client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                       channel: '#api-benefits-claims',
                                       username: 'VSOReloader')
      client.notify(message)
    end
  end
end
