# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class BaseReloader
    include Sidekiq::Worker
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

    private

    def find_or_initialize(hash_object)
      rep = Veteran::Service::Representative.find_or_initialize_by(representative_id: hash_object['Registration Num'],
                                                                   first_name: hash_object['First Name'],
                                                                   last_name: hash_object['Last Name'])
      poa_code = hash_object['POA Code'].gsub!(/\W/, '')
      rep.poa_codes << poa_code unless rep.user_types.include?(poa_code)
      rep.phone = hash_object['Phone']
      rep
    end

    def fetch_data(action)
      page = Faraday.new(url: BASE_URL).post(action, id: 'frmExcelList', name: 'frmExcelList').body
      doc = Nokogiri::HTML(page)
      headers = doc.xpath('//table/tr').first.children.map { |child| child.children.text.scrub }
      doc.xpath('//table/tr').map do |line|
        row = line.children.map { |child| child.children.text.scrub }
        Hash[headers.zip(row)].delete_if { |k, _v| k.blank? } unless headers == row
      end.compact.uniq
    end
  end
end
