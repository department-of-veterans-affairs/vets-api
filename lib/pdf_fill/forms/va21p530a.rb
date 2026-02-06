# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/forms/field_mappings/va21p530a'

module PdfFill
  module Forms
    class Va21p530a < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = FieldMappings::Va21p530a::KEY

      # Template path explicitly set due to case mismatch
      # Form ID is registered as '21P-530A' (uppercase) but PDF file is '21P-530a.pdf' (lowercase)
      TEMPLATE = 'lib/pdf_fill/forms/pdfs/21P-530a.pdf'

      # Coordinates for the 21P-530A certification signature field
      # Signature is stamped on page 2 near the "DATE SIGNED" field
      # Note: Prawn uses bottom-left origin (0,0 at bottom-left)
      # Y increases upward: y=0 is bottom, y~792 is top for letter size
      # Increasing Y moves text higher on the page
      SIGNATURE_X = 60
      SIGNATURE_Y = 690
      SIGNATURE_PAGE = 1 # zero-indexed; 1 == page 2
      SIGNATURE_SIZE = 10

      def merge_fields(options = {})
        merge_veteran_info
        merge_service_periods
        merge_burial_info
        merge_certification(options)
        merge_remarks
        @form_data
      end

      # Stamp a typed signature string onto the PDF using DatestampPdf
      #
      # @param pdf_path [String] Path to the PDF to stamp
      # @param form_data [Hash] The form data containing the signature
      # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
      def self.stamp_signature(pdf_path, form_data)
        signature_text = form_data.dig('certification', 'signature')

        # Return original path if signature is blank
        return pdf_path if signature_text.nil? || signature_text.to_s.strip.empty?

        PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: signature_text,
          x: SIGNATURE_X,
          y: SIGNATURE_Y,
          page_number: SIGNATURE_PAGE,
          size: SIGNATURE_SIZE,
          text_only: true,
          timestamp: '',
          template: pdf_path,
          multistamp: true
        )
      rescue => e
        Rails.logger.error('Form21p530a: Error stamping signature', error: e.message, backtrace: e.backtrace)
        pdf_path # Return original PDF if stamping fails
      end

      private

      def merge_veteran_info
        return unless @form_data['veteranInformation']

        vet_info = @form_data['veteranInformation']
        merge_ssn_fields(vet_info)
        merge_date_of_birth(vet_info)
        merge_date_of_death(vet_info)
        merge_place_of_birth(vet_info)
      end

      def merge_ssn_fields(vet_info)
        return unless vet_info['ssn']

        ssn = vet_info['ssn'].to_s.gsub(/\D/, '')
        ssn_parts = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }
        # Populate SSN on both page 1 and page 2
        @form_data['veteranInformation']['ssn'] = ssn_parts
        @form_data['veteranInformation']['ssnPage2'] = ssn_parts
      end

      def merge_date_of_birth(vet_info)
        return unless vet_info['dateOfBirth']

        dob = parse_date(vet_info['dateOfBirth'])
        return unless dob

        @form_data['veteranInformation']['dateOfBirth'] = {
          'month' => dob[:month],
          'day' => dob[:day],
          'year' => dob[:year]
        }
      end

      def merge_date_of_death(vet_info)
        return unless vet_info['dateOfDeath']

        dod = parse_date(vet_info['dateOfDeath'])
        return unless dod

        @form_data['veteranInformation']['dateOfDeath'] = {
          'month' => dod[:month],
          'day' => dod[:day],
          'year' => dod[:year]
        }
      end

      def merge_place_of_birth(vet_info)
        return unless vet_info['placeOfBirth']

        pob = vet_info['placeOfBirth']
        return unless pob['city'] || pob['state']

        parts = []
        parts << pob['city'] if pob['city']
        parts << pob['state'] if pob['state']
        @form_data['veteranInformation']['placeOfBirth'] = parts.join(', ')
      end

      def merge_service_periods
        return unless @form_data['veteranServicePeriods']

        service_periods = @form_data['veteranServicePeriods']

        # Format dates for service periods array
        # HashConverter will handle iteration and limit to 3 periods automatically
        if service_periods['periods'].is_a?(Array)
          @form_data['veteranServicePeriods']['periods'] = service_periods['periods'].map do |period|
            {
              'serviceBranch' => period['serviceBranch'],
              'dateEnteredService' => format_date_string(period['dateEnteredService']),
              'placeEnteredService' => period['placeEnteredService'],
              'rankAtSeparation' => period['rankAtSeparation'],
              'dateLeftService' => format_date_string(period['dateLeftService']),
              'placeLeftService' => period['placeLeftService']
            }
          end
        end
      end

      def merge_burial_info
        return unless @form_data['burialInformation']

        burial_info = @form_data['burialInformation']

        # Format date of burial (expecting MM/DD/YYYY format for this field)
        if burial_info['dateOfBurial']
          date = parse_date(burial_info['dateOfBurial'])
          @form_data['burialInformation']['dateOfBurial'] = "#{date[:month]}/#{date[:day]}/#{date[:year]}" if date
        end

        # Handle postal code splitting
        if burial_info.dig('recipientOrganization', 'address', 'postalCode')
          addr = burial_info['recipientOrganization']['address']
          postal = addr['postalCode'].to_s

          # Split ZIP code into first 5 and extension if present
          # The front end only accepts 5-digit zip codes for US addresses so
          # we should rethink how we handle this for non-US addresses
          if postal.include?('-')
            parts = postal.split('-')
            addr['postalCode'] = parts[0]
            addr['postalCodeExtension'] = parts[1] if parts[1]
          elsif postal.length > 5
            addr['postalCode'] = postal[0..4]
            addr['postalCodeExtension'] = postal[5..8]
          end
        end
      end

      def merge_certification(options = {})
        return unless @form_data['certification']

        # Auto-generate DATE SIGNED (MM/DD/YYYY format)
        # The DATE_SIGNED field should be filled with the current date or creation date
        certification_date = options[:created_at]&.to_date || Time.zone.today
        date = {
          month: certification_date.month.to_s.rjust(2, '0'),
          day: certification_date.day.to_s.rjust(2, '0'),
          year: certification_date.year.to_s
        }

        # Fill the DATE_SIGNED field in the PDF
        @form_data['certification']['dateSigned'] = "#{date[:month]}/#{date[:day]}/#{date[:year]}"
      end

      def merge_remarks
        # Remarks is a simple text field, no transformation needed
      end

      def parse_date(date_string)
        return nil unless date_string

        date = Date.parse(date_string.to_s)
        {
          month: date.month.to_s.rjust(2, '0'),
          day: date.day.to_s.rjust(2, '0'),
          year: date.year.to_s
        }
      rescue ArgumentError
        nil
      end

      def format_date_string(date_string)
        return nil unless date_string

        date = parse_date(date_string)
        return nil unless date

        "#{date[:month]}/#{date[:day]}/#{date[:year]}"
      end
    end
  end
end
