# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    # Here we need to take the query string and compare it to the full names of
    # the accredited individuals and organizations in their respective tables.
    # We need to order the records by word similarity to the query string.
    # Then those records need to be passed to the seralizer to be rendered as JSON.

    def initialize(query_string)
      @query_string = query_string
      p 'RepresentationManagement::AccreditedEntityQuery ' * 20, "query_string: #{@query_string}"
    end

    def results
      if AccreditedIndividual.count.zero? && AccreditedOrganization.count.zero?
        # Create AccreditedIndividuals
        20.times do
          FactoryBot.create(:accredited_individual)
        end
        # Create AccreditedOrganizations
        20.times do
          FactoryBot.create(:accredited_organization)
        end
      end

      individuals = AccreditedIndividual.where('word_similarity(?, full_name) >= ?', @query_string, threshold)
      organizations = AccreditedOrganization.where('word_similarity(?, name) >= ?', @query_string, threshold)
      p "individuals full_names: #{individuals.map(&:full_name).sort}",
        "organizations names: #{organizations.map(&:name).sort}"

      combined_results = (individuals + organizations).sort_by do |record|
        levenshtein_distance(@query_string, record)
      end
      p "combined_results: #{combined_results}",
        "combined_results class names: #{combined_results.map(&:class).map(&:name)}",
        "combined_results.class.name: #{combined_results.class.name}"
      combined_results
    end

    private

    def threshold
      0.5
    end

    def levenshtein_distance(query, record)
      text = record.is_a?(AccreditedIndividual) ? record.full_name : record.name
      StringHelpers.levenshtein_distance(query, text)
    end
  end
end
