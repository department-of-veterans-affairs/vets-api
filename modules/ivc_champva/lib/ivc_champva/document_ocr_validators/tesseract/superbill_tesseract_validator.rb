# frozen_string_literal: true

require_relative '../base_validator'

module IvcChampva
  module DocumentOcrValidators
    module Tesseract
      class SuperbillTesseractValidator < BaseValidator
        def suitable_for_document?(text)
          keywords = [
            'superbill',
            'procedure code',
            'cpt',
            'diagnosis',
            'provider',
            'amount charged'
          ]
          contains_keywords?(text, keywords)
        end

        def extract_fields(text)
          {
            patient_name: extract_with_patterns(text, [/patient[:\s]*([A-Za-z\s]+)/i]),
            provider_name: extract_with_patterns(text, [/provider[:\s]*([A-Za-z\s]+)/i]),
            date_of_service: extract_with_patterns(text, [%r{date of service[:\s]*([\d/]+)}i]),
            procedure_code: extract_with_patterns(text, [/procedure code[:\s]*([A-Za-z0-9]+)/i]),
            amount_charged: extract_with_patterns(text, [/amount charged[:\s]*\$?([\d.]+)/i])
          }
        end

        def valid_document?(text)
          return false unless suitable_for_document?(text)

          fields = extract_fields(text)
          fields[:patient_name] && fields[:provider_name] && fields[:date_of_service]
        end

        def confidence_score(text)
          return 0.0 unless suitable_for_document?(text)

          score = 0.3
          fields = extract_fields(text)
          score += 0.2 if fields[:patient_name]
          score += 0.2 if fields[:provider_name]
          score += 0.2 if fields[:date_of_service]
          score += 0.2 if fields[:procedure_code]
          score += 0.1 if fields[:amount_charged]
          score
        end

        def document_type
          'superbill'
        end
      end
    end
  end
end
