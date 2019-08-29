# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class VsoReloader
    include Sidekiq::Worker
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

    def perform
      array_of_organizations = reload_representatives
      Veteran::Service::Organization.import(array_of_organizations, on_duplicate_key_ignore: true)
    end

    private

    def reload_representatives
      data = fetch_data('orgsexcellist.asp')
      data.each do |hash|
        find_or_create_vso(hash)
      end

      Veteran::Service::Representative.where.not(representative_id: data.map { |h| h['Registration Num'] }).destroy_all

      array_of_organizations = data.map do |h|
        { poa: h['POA'], name: h['Organization Name'], phone: h['Org Phone'], state: h['Org State'] }
      end.uniq.compact
      array_of_organizations
    end

    def find_or_create_vso(hash)
      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: hash['Registration Num'])
      rep.poa_codes ||= []
      rep.poa_codes << hash['POA'].gsub!(/\W/, '')
      rep.first_name = hash['Representative'].split(' ').second
      rep.last_name = hash['Representative'].split(',').first
      rep.phone = hash['Org Phone']
      rep.user_types ||= []
      rep.user_types << 'VSO'
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
