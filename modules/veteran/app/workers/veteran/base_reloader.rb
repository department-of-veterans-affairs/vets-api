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
      headers = doc.xpath('//table/tr').first.children.children.map {|header| header.text }
      doc.xpath('//table/tr').map do |row|
        Hash[headers.zip(row.children.children.map {|cell| cell.text})]
      end
    end
  end
end
