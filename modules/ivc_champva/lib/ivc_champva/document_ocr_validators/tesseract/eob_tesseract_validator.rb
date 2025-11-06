# frozen_string_literal: true

require_relative '../base_validator'

module IvcChampva
  module DocumentOcrValidators
    module Tesseract
      class EobTesseractValidator < BaseValidator
        def document_type
          'explanation_of_benefits'
        end

        def suitable_for_document?(text)
          eob_keywords = [
            'explanation of benefits',
            'eob',
            'benefits explanation',
            'claim summary',
            'provider',
            'date of service',
            'amount paid',
            'patient responsibility'
          ]

          eob_keywords.any? { |keyword| text.downcase.include?(keyword) }
        end

        def extract_fields(text)
          {
            date_of_service: extract_date_of_service(text),
            provider_name: extract_provider_name(text),
            npi: extract_npi(text),
            service_code: extract_service_code(text),
            amount_paid: extract_amount_paid(text)
          }
        end

        def valid_document?(text)
          fields = extract_fields(text)
          required_fields = %i[date_of_service provider_name service_code amount_paid]
          required_fields.all? { |field| fields[field] }
        end

        def confidence_score(text)
          return 0.0 unless suitable_for_document?(text)

          base_confidence = 0.2
          fields = extract_fields(text)
          field_bonus = fields.count { |_, value| value } * 0.1

          [base_confidence + field_bonus, 1.0].min
        end

        private

        def extract_date_of_service(text)
          # Look for date patterns like MM/DD/YYYY, MM-DD-YYYY, etc.
          date_patterns = [
            %r{\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b},
            /\b(\d{1,2}\.\d{1,2}\.\d{2,4})\b/
          ]

          date_patterns.each do |pattern|
            match = text.match(pattern)
            return match[1] if match
          end

          nil
        end

        def extract_provider_name(text)
          # Look for provider patterns
          provider_patterns = [
            /provider[:\s]{1,3}([A-Za-z][A-Za-z\s,.]{0,48}[A-Za-z])/i,
            /dr\.?\s{1,3}([A-Za-z][A-Za-z\s,.]{0,48}[A-Za-z])/i,
            /([A-Za-z][A-Za-z\s,.]{0,48}[A-Za-z])\s{1,5}(?:npi|claim)/i
          ]

          provider_patterns.each do |pattern|
            match = text.match(pattern)
            next unless match

            name = match[1].strip.gsub(/[,.]+$/, '')
            return name if name.length > 2 && name.length < 50
          end

          nil
        end

        def extract_npi(text)
          # NPI is always 10 digits
          npi_match = text.match(/\b(\d{10})\b/)
          npi_match ? npi_match[1] : nil
        end

        def extract_service_code(text)
          # CPT codes (5 digits) or HCPCS codes (1 letter + 4 digits)
          service_patterns = [
            /\b([A-Z]\d{4})\b/, # HCPCS format
            /\b(\d{5})\b/       # CPT format
          ]

          service_patterns.each do |pattern|
            match = text.match(pattern)
            return match[1] if match
          end

          nil
        end

        def extract_amount_paid(text)
          # Look for currency amounts - limit the character class repetition
          amount_patterns = [
            /(?:paid|amount)[:\s]{0,5}\$?(\d{1,10}\.?\d{0,2})/i,
            /\$(\d{1,10}\.?\d{0,2})/
          ]

          amount_patterns.each do |pattern|
            match = text.match(pattern)
            return match[1] if match
          end

          nil
        end
      end
    end
  end
end
