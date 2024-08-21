# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.7

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      return [] if @query_string.blank?

      array_results = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  sql_query,
                                  {
                                    query_string: @query_string,
                                    threshold: WORD_SIMILARITY_THRESHOLD,
                                    max_results: MAXIMUM_RESULT_COUNT
                                  }
                                ])
      )

      transform_results_to_objects(array_results)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def sql_query
      <<-SQL.squish
        WITH combined AS (
          SELECT
            id,
            full_name AS name,
            'AccreditedIndividual' AS model_type,
            levenshtein(full_name, :query_string) AS distance
          FROM
            accredited_individuals
          WHERE
            word_similarity(:query_string, full_name) >= :threshold
            AND location IS NOT NULL

          UNION ALL

          SELECT
            id,
            name AS name,
            'AccreditedOrganization' AS model_type,
            levenshtein(name, :query_string) AS distance
          FROM
            accredited_organizations
          WHERE
            word_similarity(:query_string, name) >= :threshold
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
          :max_results;
      SQL
    end
    # rubocop:enable Metrics/MethodLength

    def transform_results_to_objects(array_results)
      grouped_results = array_results.group_by { |result| result['model_type'] }

      individual_ids = grouped_results['AccreditedIndividual']&.pluck('id') || []
      organization_ids = grouped_results['AccreditedOrganization']&.pluck('id') || []

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
