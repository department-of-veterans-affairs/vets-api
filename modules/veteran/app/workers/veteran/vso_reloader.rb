# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class VsoReloader < BaseReloader
    def perform
      array_of_organizations = reload_representatives
      # This Where Not statement is for removing anyone no longer on the lists pulled down from OGC
      Veteran::Service::Representative.where.not(representative_id: array_of_organizations).destroy_all
    end

    private

    def reload_representatives
      vso_reps = []
      vso_orgs = fetch_data('orgsexcellist.asp').map do |vso_rep|
        find_or_create_vso(vso_rep)
        vso_reps << vso_rep['Registration Num']
        { poa: vso_rep['POA'], name: vso_rep['Organization Name'], phone: vso_rep['Org Phone'], state: vso_rep['Org State'] }
      end
      Veteran::Service::Organization.import(vso_orgs, on_duplicate_key_ignore: true)

      attorneys = fetch_data('attorneyexcellist.asp').map do |attorney|
        find_or_create_attorneys(attorney)
        attorney['Registration Num']
      end

      claim_agents = fetch_data('caexcellist.asp').map do |claim_agent|
        find_or_create_claim_agents(claim_agent)
        claim_agent['Registration Num']
      end

      vso_reps + attorneys + claim_agents
    end

    def find_or_create_attorneys(attorney)
      rep = find_or_initialize(attorney)
      rep.user_types << 'attorney'
      rep.save
    end

    def find_or_create_claim_agents(claim_agent)
      rep = find_or_initialize(claim_agent)
      rep.user_types << 'claim_agents'
      rep.save
    end

    def find_or_create_vso(vso)
      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: vso['Registration Num'],
                                                                   first_name: vso['Representative'].split(' ').second,
                                                                   last_name: vso['Representative'].split(',').first)
      rep.poa_codes ||= []
      rep.poa_codes << vso['POA'].gsub!(/\W/, '')
      rep.phone = vso['Org Phone']
      rep.user_types ||= []
      rep.user_types << 'veteran_service_officer'
      rep.save
    end
  end
end
