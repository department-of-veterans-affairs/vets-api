# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class BaseReloader
    include Sidekiq::Worker
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

    private

    def find_or_initialize(hash)
      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: hash['Registration Num'],
                                                                   first_name: hash['First Name'],
                                                                   last_name: hash['Last Name'])
      rep.poa_codes ||= []
      rep.user_types ||= []
      rep.poa_codes << hash['POA Code'].gsub!(/\W/, '')
      rep.phone = hash['Phone']
      rep
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
