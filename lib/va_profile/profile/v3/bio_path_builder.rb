# frozen_string_literal: true

module VAProfile
  module Profile
    module V3
      class BioPathBuilder
        BIO_PATHS = {
          military_admin_decisions: 'militaryPerson.adminDecisions',
          military_admin_eposides: 'militaryPerson.adminEpisodes',
          military_dental_indicators: 'militaryPerson.dentalIndicators',
          military_occupations: 'militaryPerson.militaryOccupations',
          military_service_history: 'militaryPerson.militaryServiceHistory',
          military_summary: 'militaryPerson.militarySummary',
          military_dod_service_summary: 'militaryPerson.militarySummary.customerType.dodServiceSummary',
          military_pay_grade_ranks: 'militaryPerson.payGradeRanks',
          military_prisoner_of_wars: 'militaryPerson.prisonerOfWars',
          military_transfer_of_eligibility: 'militaryPerson.transferOfEligibility',
          military_retirements: 'militaryPerson.retirements',
          military_separation_pays: 'militaryPerson.separationPays',
          military_retirement_pays: 'militaryPerson.retirementPays',
          military_combat_pays: 'militaryPerson.combatPays',
          military_unit_assignments: 'militaryPerson.unitAssignments'
        }.freeze

        def initialize(*bio_paths)
          @bio_paths = []
          return unless bio_paths

          if bio_paths.include?(:all)
            @bio_paths = add_all_bio_paths
          else
            bio_paths.each { |bio_path| add_bio_path(bio_path) }
          end
        end

        def add_bio_path(bio_path)
          raise ArgumentError, "Invalid bio path: #{bio_path}" unless bio_path_exists?(bio_path)

          @bio_paths << { bioPath: BIO_PATHS[bio_path] }
        end

        def bio_path_exists?(bio_path)
          BIO_PATHS.key?(bio_path.to_sym) if bio_path
        end

        def params
          { bios: @bio_paths }
        end

        def add_all_bio_paths
          BIO_PATHS.each_key { |key| add_bio_path(key) }
        end
      end
    end
  end
end
