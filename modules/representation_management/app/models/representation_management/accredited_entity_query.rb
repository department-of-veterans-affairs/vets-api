# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    WORD_SIMILARITY_THRESHOLD = 0.7
    MAXIMUM_RESULT_COUNT = 10

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      (individuals + organizations).sort_by do |record|
        levenshtein_distance(@query_string, record)
      end.take(MAXIMUM_RESULT_COUNT)
    end

    private

    def individuals
      AccreditedIndividual.where('word_similarity(?, full_name) >= ?', @query_string, WORD_SIMILARITY_THRESHOLD)
    end

    def organizations
      AccreditedOrganization.where('word_similarity(?, name) >= ?', @query_string, WORD_SIMILARITY_THRESHOLD)
    end

    def levenshtein_distance(query, record)
      text = record.is_a?(AccreditedIndividual) ? record.full_name : record.name
      StringHelpers.levenshtein_distance(query, text)
    end
  end
end
