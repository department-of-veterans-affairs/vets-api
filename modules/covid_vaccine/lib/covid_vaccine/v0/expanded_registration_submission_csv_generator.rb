# frozen_string_literal: true

require 'stringio'

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmissionCSVGenerator
      VA_AGENCY_IDENTIFIER = '8'

      MAPPER = {
        first_name: proc { |r| r.raw_form_data['first_name'] },
        middle_name: proc { |r| r.raw_form_data['middle_name'] },
        last_name: proc { |r| r.raw_form_data['last_name'] },
        birth_date: proc { |r| Date.parse(r.raw_form_data['birth_date']).strftime('%m/%d/%Y') },
        ssn: proc { |r| r.raw_form_data['ssn'] },
        birth_sex: proc { |r| r.raw_form_data['birth_sex'][0] },
        icn: proc { |r| r.eligibility_info&.fetch('icn', nil) },
        address: proc do |r|
                   [
                     r.raw_form_data['address_line1'],
                     r.raw_form_data['address_line2'],
                     r.raw_form_data['address_line3']
                   ].join(' ').strip
                 end,
        city: proc { |r| r.raw_form_data['city'] },
        state_code: proc { |r| r.raw_form_data['state_code'] },
        zip_code: proc { |r| r.raw_form_data['zip_code'] },
        phone: proc { |r| r.raw_form_data['phone'].delete('-').insert(0, '(').insert(4, ')') },
        email_address: proc { |r| r.raw_form_data['email_address'] },
        preferred_facility: proc { |r| r.raw_form_data['preferred_facility']&.delete_prefix('vha_') },
        agency_id: proc { |_r| VA_AGENCY_IDENTIFIER }
      }.freeze

      def initialize(records)
        @records = records
        @mapped_rows = records.map do |record|
          MAPPER.map do |_field, mapping|
            mapping.call(record)
          end
        end
      end

      def csv
        @csv ||= CSV.generate(col_sep: '^') do |csv|
          csv << MAPPER.keys
          @mapped_rows.each do |row|
            csv << row.map { |field| field&.delete('"^') }
          end
        end
    
      def io
        @io ||= StringIO.new(csv)
      end
    end
  end
end
