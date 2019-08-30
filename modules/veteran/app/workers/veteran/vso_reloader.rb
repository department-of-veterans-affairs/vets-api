# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class VsoReloader < BaseReloader
    include Sidekiq::Worker
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

    def perform
      array_of_organizations = reload_representatives
      Veteran::Service::Representative.where.not(representative_id: array_of_organizations).destroy_all
    end

    private

    def reload_representatives
      vso_reps = []
      vso_orgs = fetch_data('orgsexcellist.asp').map do |hash|
        find_or_create_vso(hash)
        vso_reps << hash['Registration Num']
        { poa: hash['POA'], name: hash['Organization Name'], phone: hash['Org Phone'], state: hash['Org State'] }
      end
      Veteran::Service::Organization.import(vso_orgs, on_duplicate_key_ignore: true)

      attorneys = fetch_data('attorneyexcellist.asp').map do |hash|
        find_or_create_attorneys(hash)
        hash['Registration Num']
      end

      claim_agents = fetch_data('caexcellist.asp').map do |hash|
        find_or_create_claim_agents(hash)
        hash['Registration Num']
      end

      vso_reps + attorneys + claim_agents
    end

    def find_or_create_attorneys(hash)
      rep = find_or_initialize(hash)
      rep.poa_codes << hash['POA Code'].gsub!(/\W/, '')
      rep.phone = hash['Phone']
      rep.user_types << 'attorney'
      rep.save
    end

    def find_or_create_claim_agents(hash)
      rep = find_or_initialize(hash)
      rep.poa_codes << hash['POA Code'].gsub!(/\W/, '')
      rep.phone = hash['Phone']
      rep.user_types << 'claim_agents'
      rep.save
    end

    def find_or_create_vso(hash)
      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: hash['Registration Num'],
                                                                   first_name: hash['Representative'].split(' ').second,
                                                                   last_name: hash['Representative'].split(',').first)
      rep.poa_codes ||= []
      rep.poa_codes << hash['POA'].gsub!(/\W/, '')
      rep.phone = hash['Org Phone']
      rep.user_types ||= []
      rep.user_types << 'veteran_service_officer'
      rep.save
    end

    def fetch_data(action)
      page = Faraday.new(url: BASE_URL).post(action, id: 'frmExcelList', name: 'frmExcelList').body
      doc = Nokogiri::HTML(page)
      content = CSV.generate(headers: true) do |csv|
        doc.xpath('//table/tr').each do |row|
          tarray = []
          row.xpath('td').each do |cell|
            tarray << cell.text.scrub
          end
          csv << tarray
        end
      end
      CSV.parse(content, headers: :first_row).map(&:to_h)
    end
  end
end
