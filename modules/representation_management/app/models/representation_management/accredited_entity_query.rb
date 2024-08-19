# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.5

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      sanitized_query_string = ActiveRecord::Base.connection.quote(@query_string)
      sql = <<-SQL
        WITH combined AS (
          SELECT
            id,
            'AccreditedIndividual' AS model_type,
            full_name AS name,
            word_similarity(full_name, #{sanitized_query_string}) AS word_similarity_score,
            levenshtein(full_name, #{sanitized_query_string}) AS distance
          FROM
            accredited_individuals
          WHERE
            word_similarity(full_name, #{sanitized_query_string}) > #{WORD_SIMILARITY_THRESHOLD}
            AND location IS NOT NULL

          UNION ALL

          SELECT
            id,
            'AccreditedOrganization' AS model_type,
            name AS name,
            word_similarity(name, #{sanitized_query_string}) AS word_similarity_score,
            levenshtein(name, #{sanitized_query_string}) AS distance
          FROM
            accredited_organizations
          WHERE
            word_similarity(name, #{sanitized_query_string}) > #{WORD_SIMILARITY_THRESHOLD}
            AND location IS NOT NULL
        )
        SELECT
          id,
          model_type,
          distance
        FROM
          combined
        ORDER BY
          distance ASC
        LIMIT
          #{MAXIMUM_RESULT_COUNT};
      SQL

      array_results = ActiveRecord::Base.connection.exec_query(sql)
      transform_results_to_objects(array_results)
    end

    private

    def transform_results_to_objects(array_results)
      individual_ids = array_results.select do |result|
        result['model_type'] == 'AccreditedIndividual'
      end.pluck('id')
      organization_ids = array_results.select do |result|
        result['model_type'] == 'AccreditedOrganization'
      end.pluck('id')

      individuals = AccreditedIndividual.where(id: individual_ids).index_by(&:id)
      organizations = AccreditedOrganization.where(id: organization_ids).index_by(&:id)

      array_results.map do |result|
        model_type = result['model_type']
        id = result['id']
        model_type == 'AccreditedIndividual' ? individuals[id] : organizations[id]
      end
    end
  end
end
