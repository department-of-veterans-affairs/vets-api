# frozen_string_literal: true

require 'csv'

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < ApplicationRecord
      BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

      self.primary_key = :representative_id

      validates_presence_of :poa

      def self.reload!
        array_of_hashes = fetch_data('orgsexcellist.asp')
        array_of_hashes.each do |hash|
          find_or_create_representative(hash)
        end

        Representative.where.not(representative_id: array_of_hashes.map { |h| h['Registration Num'] }).destroy_all

        array_of_organizations = array_of_hashes.map do |h|
          { poa: h['POA'], name: h['Organization Name'], phone: h['Org Phone'], state: h['Org State'] }
        end.uniq.compact

        Organization.import(array_of_organizations, on_duplicate_key_ignore: true)
      end

      def self.find_or_create_representative(hash)
        representative = Representative.find_or_initialize_by(representative_id: hash['Registration Num'])
        representative.poa = hash['POA'].gsub!(/\W/, '')
        representative.first_name = hash['Representative'].split(' ').second
        representative.last_name = hash['Representative'].split(',').first
        representative.phone = hash['Org Phone']
        representative.save
      end

      def self.fetch_data(action)
        page = Faraday.new(url: BASE_URL).post(action, id: 'frmExcelList', name: 'frmExcelList').body
        doc = Nokogiri::HTML(page)
        content = CSV.generate(headers: true) do |csv|
          doc.xpath('//table/tr').each do |row|
            tarray = []
            row.xpath('td').each do |cell|
              tarray << cell.text
            end
            csv << tarray
          end
        end
        CSV.parse(content, headers: :first_row).map(&:to_h)
      end
    end
  end
end
