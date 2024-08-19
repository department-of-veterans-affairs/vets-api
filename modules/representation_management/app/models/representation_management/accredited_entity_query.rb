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
      return [] if @query_string.blank?

      (individuals + organizations).sort_by(&:distance).take(MAXIMUM_RESULT_COUNT)
    end

    private

    def individuals
      query = ActiveRecord::Base.connection.quote(@query_string) # Safely quote the query string
      AccreditedIndividual
        .select("accredited_individuals.*, levenshtein(accredited_individuals.full_name, #{query}) AS distance")
        .order('distance ASC')
        .limit(MAXIMUM_RESULT_COUNT)
    end

    def organizations
      query = ActiveRecord::Base.connection.quote(@query_string) # Safely quote the query string
      AccreditedOrganization
        .select("accredited_organizations.*, levenshtein(accredited_organizations.name, #{query}) AS distance")
        .order('distance ASC')
        .limit(MAXIMUM_RESULT_COUNT)
    end
  end
end
