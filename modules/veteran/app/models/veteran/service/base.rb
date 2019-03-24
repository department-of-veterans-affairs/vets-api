# frozen_string_literal: true

require 'nokogiri'
require 'csv'

module Veteran
    # Not technically a Service Object, this is a term used by the VA internally.
    module Service
      class Base < ActiveRecord::Base
        BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

        validates_presence_of :poa
  
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
  