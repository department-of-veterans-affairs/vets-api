# frozen_string_literal: true

require_relative '../base_validator'

module IvcChampva
  module DocumentOcrValidators
    module Tesseract
      class SocialSecurityCardTesseractValidator < BaseValidator
        def suitable_for_document?(text)
          ssn_keywords = [
            'social security',
            'social security number',
            'ssn',
            'social security administration',
            'ssa'
          ]

          ssn_keywords.any? { |keyword| text.downcase.include?(keyword) }
        end

        def extract_fields(text)
          {
            ssn: extract_ssn(text),
            name: extract_name(text)
          }
        end

        def valid_document?(text)
          return false unless suitable_for_document?(text)

          fields = extract_fields(text)
          !!(fields[:ssn] && fields[:name])
        end

        def confidence_score(text)
          return 0.0 unless suitable_for_document?(text)

          score = 0.3 # Base score for having SSN keywords
          fields = extract_fields(text)

          score += 0.4 if fields[:ssn]
          score += 0.3 if fields[:name]

          score
        end

        def document_type
          'social_security_card'
        end

        private

        def extract_ssn(text)
          # Look for SSN patterns: XXX-XX-XXXX, XXX XX XXXX, or XXXXXXXXX
          ssn_patterns = [
            /\b(\d{3}-\d{2}-\d{4})\b/,
            /\b(\d{3}\s\d{2}\s\d{4})\b/,
            /\b(\d{9})\b/
          ]

          ssn_patterns.each do |pattern|
            match = text.match(pattern)
            return normalize_ssn(match[1]) if match
          end

          nil
        end

        def extract_name(text)
          # Look for name patterns - typically after "NAME" or similar labels
          name_patterns = [
            /name[:\s]+([A-Z][A-Za-z\s,]+?)(?:\s+social|\s+\d{3}|$)/i,
            /established\s+for\s+([A-Z][A-Za-z\s,]+?)(?:\s+\d{3}|$)/i,
            /\bfor\s+([A-Z][A-Za-z\s,]+?)\s+\d{3}/i,
            /^NAME\s+([A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+)\s+social/i,
            /^([A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+)\s+\d{3}/
          ]

          name_patterns.each do |pattern|
            match = text.match(pattern)
            next unless match

            name = match[1].strip.gsub(/\s+(social|security|administration|ssa|ssn)$/i, '').gsub(/[,\.]+$/, '')
            return name if valid_name?(name)
          end

          nil
        end

        def normalize_ssn(ssn)
          # Remove any spaces or dashes and format as XXX-XX-XXXX
          clean_ssn = ssn.gsub(/\D/, '')
          return nil unless clean_ssn.length == 9

          "#{clean_ssn[0..2]}-#{clean_ssn[3..4]}-#{clean_ssn[5..8]}"
        end

        def valid_name?(name)
          return false if name.nil? || name.strip.empty?

          # Basic length validation
          return false if name.length < 4 || name.length > 50

          # Must contain only letters and spaces
          return false unless name.match?(/^[A-Za-z\s]+$/)

          # Reject common non-name phrases
          invalid_phrases = [
            'no name', 'name here', 'social security', 'administration',
            'established', 'number', 'card', 'here', 'there'
          ]

          normalized_name = name.downcase.strip
          return false if invalid_phrases.any? { |phrase| normalized_name.include?(phrase) }

          # Must have at least two words (first and last name)
          words = name.strip.split(/\s+/)
          return false if words.length < 2

          # First and last words should be at least 2 characters, middle initials can be 1
          return false if words.first.length < 2 || words.last.length < 2

          # Middle words (if any) can be single letters (initials) or longer names
          true
        end
      end
    end
  end
end
