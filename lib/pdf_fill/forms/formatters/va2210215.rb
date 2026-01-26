# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va2210215 < Base
        class << self
          def format_phone_number(phone_number)
            phone_number.gsub(/(\d{3})(\d{3})(\d{4})/, '(\1) \2-\3')
          end

          def format_zero_as(value, replacement)
            value.to_f.zero? ? replacement : value
          end

          def combine_official_name(form_data)
            official = form_data['certifyingOfficial']
            return unless official

            official['fullName'] = "#{official['first']} #{official['last']}" if official['first'] && official['last']
          end

          def process_programs(form_data)
            return unless form_data['programs']

            calculation_date = form_data.dig('institutionDetails', 'dateOfCalculations')

            form_data['programs'].each do |program|
              program['programDateOfCalculation'] = calculation_date if calculation_date
              process_fte(program['fte']) if program['fte']
            end
          end

          def process_fte(fte)
            numeric_fields = %w[supported nonSupported totalFTE]
            percentage_fields = %w[supportedPercentageFTE]

            numeric_fields.each { |field| fte[field] = format_numeric_fte_value(fte[field]) if fte[field].present? }
            percentage_fields.each do |field|
              fte[field] = format_percentage_fte_value(fte[field]) if fte[field].present?
            end
          end

          def sort_programs_by_name(programs)
            return [] if programs.blank?

            programs.sort_by do |program|
              program_name = program['programName']
              # Treat nil or missing programName as empty string for sorting
              program_name.nil? ? '' : program_name.to_s.downcase
            end
          end

          private

          def format_numeric_fte_value(value)
            value.to_f.zero? ? '--' : format('%.2f', value)
          end

          def format_percentage_fte_value(value)
            value.to_f.zero? ? 'N/A' : "#{format('%.2f', value)}%"
          end
        end
      end
    end
  end
end
