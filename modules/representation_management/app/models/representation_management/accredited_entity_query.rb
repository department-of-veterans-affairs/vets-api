# frozen_string_literal: true

module RepresentationManagement
  class AccreditedEntityQuery
    include ActiveModel::Model

    def initialize(query_string)
      @query_string = query_string
    end

    def results
      create_accredited_entities if AccreditedIndividual.count.zero? && AccreditedOrganization.count.zero?

      (individuals + organizations).sort_by do |record|
        levenshtein_distance(@query_string, record)
      end
    end

    private

    def individuals
      AccreditedIndividual.where('word_similarity(?, full_name) >= ?', @query_string, threshold)
    end

    def organizations
      AccreditedOrganization.where('word_similarity(?, name) >= ?', @query_string, threshold)
    end

    def threshold
      0.5
    end

    def levenshtein_distance(query, record)
      text = record.is_a?(AccreditedIndividual) ? record.full_name : record.name
      StringHelpers.levenshtein_distance(query, text)
    end

    def create_accredited_entities
      # Create AccreditedIndividuals
      20.times do
        FactoryBot.create(:accredited_individual)
      end
      # Create AccreditedOrganizations
      20.times do
        FactoryBot.create(:accredited_organization)
      end
      AccreditedIndividual.find_each do |individual|
        next if individual.accredited_organizations.any?

        individual.accredited_organizations << AccreditedOrganization.all.sample
      end
    end
  end
end
