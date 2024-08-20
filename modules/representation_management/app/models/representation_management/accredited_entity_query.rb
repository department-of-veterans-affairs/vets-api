# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    MAXIMUM_RESULT_COUNT = 10
    WORD_SIMILARITY_THRESHOLD = 0.7

    def initialize(query_string)
      @query_string = query_string
    end

    # rubocop:disable Metrics/MethodLength
    def results
      return [] if @query_string.blank?

      sql = <<-SQL.squish
        WITH combined AS (
          SELECT
            id,
            'AccreditedIndividual' AS model_type,
            full_name AS name,
            levenshtein(full_name, ?) AS distance
          FROM
            accredited_individuals
          WHERE
            word_similarity(?, full_name) >= ?
            AND location IS NOT NULL

          UNION ALL

          SELECT
            id,
            'AccreditedOrganization' AS model_type,
            name AS name,
            levenshtein(name, ?) AS distance
          FROM
            accredited_organizations
          WHERE
            word_similarity(?, name) >= ?
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
          ?;
      SQL

      array_results = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  sql,
                                  @query_string, @query_string,
                                  WORD_SIMILARITY_THRESHOLD,
                                  @query_string, @query_string,
                                  WORD_SIMILARITY_THRESHOLD,
                                  MAXIMUM_RESULT_COUNT
                                ])
      )

      transform_results_to_objects(array_results)
    end
    # rubocop:enable Metrics/MethodLength

    private

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
