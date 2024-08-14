# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      (individuals + organizations).sort_by do |record|
        levenshtein_distance(@query_string, record)
      end.take(10)
    end

    private

    def individuals
      AccreditedIndividual.where('word_similarity(?, full_name) >= ?', @query_string, threshold)
    end

    def organizations
      AccreditedOrganization.where('word_similarity(?, name) >= ?', @query_string, threshold)
    end

    def threshold
      0.7
    end

    def levenshtein_distance(query, record)
      text = record.is_a?(AccreditedIndividual) ? record.full_name : record.name
      StringHelpers.levenshtein_distance(query, text)
    end
  end
end
