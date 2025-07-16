# frozen_string_literal: true

require_relative '../base_validator'

module IvcChampva
  module DocumentOcrValidators
    module Tesseract
      class PharmacyClaimTesseractValidator < BaseValidator
        def suitable_for_document?(text)
          keywords = [
            'pharmacy claim',
            'rx',
            'prescription',
            'medication',
            'pharmacy',
            'ndc'
          ]
          contains_keywords?(text, keywords)
        end

        def extract_fields(text)
          {
            patient_name: extract_with_patterns(text, [/patient[:\s]*([A-Za-z\s]+)/i]),
            rx_number: extract_with_patterns(text, [/rx[:\s#]*([A-Za-z0-9]+)/i]),
            ndc: extract_with_patterns(text, [/ndc[:\s#]*([A-Za-z0-9]+)/i]),
            date_filled: extract_with_patterns(text, [%r{date filled[:\s]*([\d/]+)}i]),
            medication: extract_with_patterns(text, [/medication[:\s]*([A-Za-z\s]+)/i])
          }
        end

        def valid_document?(text)
          return false unless suitable_for_document?(text)

          fields = extract_fields(text)
          fields[:patient_name] && fields[:rx_number] && fields[:ndc]
        end

        def confidence_score(text)
          return 0.0 unless suitable_for_document?(text)

          score = 0.3
          fields = extract_fields(text)
          score += 0.2 if fields[:patient_name]
          score += 0.2 if fields[:rx_number]
          score += 0.2 if fields[:ndc]
          score += 0.2 if fields[:date_filled]
          score += 0.1 if fields[:medication]
          score
        end

        def document_type
          'pharmacy_claim'
        end
      end
    end
  end
end
