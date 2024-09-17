# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.7

    # Initializes a new instance of AccreditedEntityQuery.
    #
    # @param query_string [String] the string to be used for querying accredited entities.
    def initialize(query_string)
      @query_string = query_string
    end

    # Executes the query and returns the results as an array of objects.
    #
    # @return [Array<AccreditedIndividual, AccreditedOrganization>] an array of accredited entities
    #   that match the query string, sorted by their similarity distance. The array will be empty
    #   if the query string is blank.
    def results
      return [] if @query_string.blank?

      array_results = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  sql_query_to_select_and_sort_accredited_entities,
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
    # Generates the SQL query used to search for accredited entities.
    #
    # @return [String] the SQL query string. The query retrieves both accredited individuals and
    #   organizations that have a name similar to the query string, using the Levenshtein distance
    #   for sorting results.
    def sql_query_to_select_and_sort_accredited_entities
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

    # Transforms the raw SQL results into an array of accredited entity objects.
    #
    # @param array_results [Array<Hash>] an array of hashes representing the raw results from the SQL query.
    #   Each hash contains an `id`, `model_type`, and `distance`.
    # @return [Array<AccreditedIndividual, AccreditedOrganization>] an array of instantiated objects
    #   corresponding to the IDs in the raw results. Each object is either an `AccreditedIndividual`
    #   or an `AccreditedOrganization` based on the `model_type` in the result.
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
