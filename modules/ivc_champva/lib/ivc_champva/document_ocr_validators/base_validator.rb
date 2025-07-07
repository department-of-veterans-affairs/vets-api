# frozen_string_literal: true

module IvcChampva
  module DocumentOcrValidators
    class BaseValidator
      # Abstract method - must be implemented by subclasses
      # @param text [String] The OCR extracted text
      # @return [Boolean] true if this validator can handle the document type
      def suitable_for_document?(text)
        raise NotImplementedError, 'Subclasses must implement suitable_for_document?'
      end

      # Abstract method - extract relevant fields from the document
      # @param text [String] The OCR extracted text
      # @return [Hash] Hash of extracted field names and values
      def extract_fields(text)
        raise NotImplementedError, 'Subclasses must implement extract_fields'
      end

      # Abstract method - validate if document contains required information
      # @param text [String] The OCR extracted text
      # @return [Boolean] true if document is valid
      def valid_document?(text)
        raise NotImplementedError, 'Subclasses must implement valid_document?'
      end

      # Abstract method - calculate confidence score of extraction
      # @param text [String] The OCR extracted text
      # @return [Float] confidence score between 0.0 and 1.0
      def confidence_score(text)
        raise NotImplementedError, 'Subclasses must implement confidence_score'
      end

      # Abstract method - return the document type this validator handles
      # @return [String] document type identifier
      def document_type
        raise NotImplementedError, 'Subclasses must implement document_type'
      end

      # Process and cache results for the given text
      def process_and_cache(text)
        return unless suitable_for_document?(text)

        @cached_extracted_fields = extract_fields(text)
        @cached_validity = valid_document?(text)
        @cached_confidence_score = confidence_score(text)

        @cached_confidence_score
      end

      # Cached result accessors
      attr_reader :cached_extracted_fields

      attr_reader :cached_validity, :cached_confidence_score

      # Check if results have been cached
      def results_cached?
        !@cached_confidence_score.nil?
      end

      protected

      # Helper method to extract text using regex patterns
      # @param text [String] The text to search
      # @param patterns [Array<Regexp>] Array of regex patterns to try
      # @return [String, nil] The extracted value or nil if not found
      def extract_with_patterns(text, patterns)
        patterns.each do |pattern|
          match = text.match(pattern)
          return match[1]&.strip if match
        end
        nil
      end

      # Helper method to check if text contains required keywords
      # @param text [String] The text to search
      # @param keywords [Array<String>] Array of required keywords
      # @return [Boolean] true if all keywords are found
      def contains_keywords?(text, keywords)
        return false if text.blank?

        normalized_text = text.downcase
        keywords.all? { |keyword| normalized_text.include?(keyword.downcase) }
      end
    end
  end
end
