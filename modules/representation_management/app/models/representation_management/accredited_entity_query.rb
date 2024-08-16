# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.3

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      combined_results = individuals + organizations
      combined_results.sort_by { |entity| entity['distance'] }.take(MAXIMUM_RESULT_COUNT)
    end

    private

    def individuals
      sanitized_query = ActiveRecord::Base.sanitize_sql(['levenshtein(full_name, ?)', @query_string])
      AccreditedIndividual.where('word_similarity(full_name, ?) > ?', @query_string, WORD_SIMILARITY_THRESHOLD)
                          .order(Arel.sql(sanitized_query))
                          .limit(MAXIMUM_RESULT_COUNT)
    end

    def organizations
      sanitized_query = ActiveRecord::Base.sanitize_sql(['levenshtein(name, ?)', @query_string])
      AccreditedOrganization.where('word_similarity(name, ?) > ?', @query_string, WORD_SIMILARITY_THRESHOLD)
                            .order(Arel.sql(sanitized_query))
                            .limit(MAXIMUM_RESULT_COUNT)
    end
  end
end
