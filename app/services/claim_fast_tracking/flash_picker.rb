# frozen_string_literal: true

module ClaimFastTracking
  class FlashPicker
    DEFAULT_FUZZY_TOLERANCE = 0.2
    MIN_FUZZY_MATCH_LENGTH = 6
    MIN_LENGTH_RATIO = 0.9

    ALS_DC = 8017
    ALS_PARTIAL_MATCH_TERMS = [
      'amyotrophic lateral sclerosis',
      '(als)'
    ].freeze
    ALS_MATCH_TERMS = (ALS_PARTIAL_MATCH_TERMS + [
      'als',
      'lou gehrig disease',
      'lou gehrigs disease',
      'lou gehrig\'s disease',
      'lou gehrig',
      'lou gehrigs',
      'lou gehrig\'s'
    ]).freeze

    def self.als?(claimed_disabilities)
      return if claimed_disabilities.pluck('diagnosticCode').include?(ALS_DC)

      claimed_disabilities.map { |disability| disability['name']&.downcase }.compact.any? do |name|
        partial_matches?(name, ALS_PARTIAL_MATCH_TERMS) || matches?(name, ALS_MATCH_TERMS)
      end
    end

    def self.partial_matches?(name, match_terms)
      match_terms = [match_terms] unless match_terms.is_a?(Array)

      match_terms.any? { |term| name.include?(term) }
    end

    def self.matches?(name,
                      match_terms,
                      tolerance = DEFAULT_FUZZY_TOLERANCE,
                      min_length_ratio = MIN_LENGTH_RATIO,
                      min_length_limit = MIN_FUZZY_MATCH_LENGTH)
      match_terms = [match_terms] unless match_terms.is_a?(Array)

      match_terms.any? do |term|
        # Early exact match check (case insensitive)
        return true if name.casecmp?(term)

        # Prevent fuzzy matching for very short terms (e.g., less than min_length_limit)
        next false if name.length < min_length_limit || term.length < min_length_limit

        # Calculate the length ratio based on the shorter and longer lengths
        shorter_length = [name.length, term.length].min
        longer_length = [name.length, term.length].max

        # Skip comparison if the length ratio is below minimum length ratio, indicating a significant length difference
        next false if shorter_length.to_f / longer_length < min_length_ratio

        # Calculate the Levenshtein threshold based on tolerance and maximum length
        return true if fuzzy_match?(name, term, longer_length, tolerance)
      end
    end

    def self.fuzzy_match?(name, term, longer_length, tolerance = DEFAULT_FUZZY_TOLERANCE)
      threshold = (longer_length * tolerance).ceil
      distance = StringHelpers.levenshtein_distance(name, term)

      if distance - 1 == threshold
        Rails.logger.info(
          'FlashPicker close fuzzy match for condition',
          { name:, match_term: term, distance:, threshold: }
        )
      end
      distance <= threshold
    end

    private_class_method :partial_matches?, :matches?, :fuzzy_match?
  end
end
