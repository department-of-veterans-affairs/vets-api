# frozen_string_literal: true

module RepresentationManagement
  class OriginalEntityQuery
    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.7

    # Initializes a new instance of OriginalEntityQuery.
    #
    # @param query_string [String] the string to be used for querying veteran_x entities.
    def initialize(query_string)
      @query_string = query_string
    end

    # Executes the query and returns the results as an array of objects.
    #
    # @return [Array<Veteran::Service::Representative, Veteran::Service::Organization>] an array of veteran_x entities
    #   that match the query string, sorted by their similarity distance. The array will be empty
    #   if the query string is blank.
    def results
      return [] if @query_string.blank?

      array_results = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  sql_query_to_select_and_sort_original_entities,
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
    # Generates the SQL query used to search for original entities.
    #
    # @return [String] the SQL query string. The query retrieves both representatives and
    #   organizations that have a name similar to the query string, using the Levenshtein distance
    #   for sorting results.
    def sql_query_to_select_and_sort_original_entities
      <<-SQL.squish
        WITH combined AS (
          SELECT
            representative_id AS id,
            full_name AS name,
            'Veteran::Service::Representative' AS model_type,
            levenshtein(full_name, :query_string) AS distance
          FROM
            veteran_representatives
          WHERE
            word_similarity(:query_string, full_name) >= :threshold
            AND location IS NOT NULL

          UNION ALL

          SELECT
            poa AS id,
            name AS name,
            'Veteran::Service::Organization' AS model_type,
            levenshtein(name, :query_string) AS distance
          FROM
            veteran_organizations
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

    # Transforms the raw SQL results into an array of original entity objects.
    #
    # @param array_results [Array<Hash>] an array of hashes representing the raw results from the SQL query.
    #   Each hash contains an `id`, `model_type`, and `distance`.
    # @return [Array<Veteran::Service::Representative, Veteran::Service::Organization>] an array of instantiated objects
    #   corresponding to the IDs in the raw results. Each object is either an `Veteran::Service::Representative`
    #   or an `Veteran::Service::Organization` based on the `model_type` in the result.
    def transform_results_to_objects(array_results)
      grouped_results = array_results.group_by { |result| result['model_type'] }

      representative_ids = grouped_results['Veteran::Service::Representative']&.pluck('id') || []
      organization_ids = grouped_results['Veteran::Service::Organization']&.pluck('id') || []

      representatives = Veteran::Service::Representative.where(representative_id: representative_ids).index_by(&:id)
      organizations = Veteran::Service::Organization.where(poa: organization_ids).index_by(&:id)

      array_results.map do |result|
        model_type = result['model_type']
        id = result['id']
        model_type == 'Veteran::Service::Representative' ? representatives[id] : organizations[id]
      end
    end
  end
end
