# frozen_string_literal: true

require 'va_profile/prefill/military_information'
require 'claims_api/service_branch_mapper'
require 'form_profile'
require 'vets/model'

module Pension21p527ez
  ##
  # extends FormMilitaryInformation to add additional military information fields to Pension prefill.
  # @see app/models/form_profile.rb FormMilitaryInformation
  class PensionFormMilitaryInformation < FormMilitaryInformation
    include Vets::Model

    attribute :first_uniformed_entry_date, String
    attribute :last_active_discharge_date, String
    attribute :service_branches_for_pensions, Hash
    attribute :service_number, String
  end

  ##
  # extends MilitaryInformation to add additional prefill methods to Pensions military information prefill
  # @see lib/va_profile/prefill/military_information.rb VAProfile::Prefill::MilitaryInformation
  class PensionMilitaryInformation < VAProfile::Prefill::MilitaryInformation
    PREFILL_METHODS = VAProfile::Prefill::MilitaryInformation::PREFILL_METHODS + %w[
      first_uniformed_entry_date
      last_active_discharge_date
      service_branches_for_pensions
      service_number
    ].freeze

    ##
    # Map between service branch names and the fields used for pensions.serviceBranch
    # @see https://api.va.gov/services/benefits-reference-data/v1/service-branches
    PENSION_SERVICE_BRANCHES_MAPPING = {
      'Army' => 'army',
      'Navy' => 'navy',
      'Air Force' => 'airForce',
      'Coast Guard' => 'coastGuard',
      'Marine Corps' => 'marineCorps',
      'Space Force' => 'spaceForce',
      'Public Health Service' => 'usphs',
      'National Oceanic & Atmospheric Administration' => 'noaa'
    }.freeze

    def initialize(user)
      @user = user
      super
    end

    # @return [String] "YYYY-MM-DD"
    def first_uniformed_entry_date
      service_history.uniformed_service_initial_entry_date
    end

    # @return [String] "YYYY-MM-DD"
    def last_active_discharge_date
      service_history.release_from_active_duty_date
    end

    # @return [Hash] { army => true, navy => true, ... } in the format required for pensions.serviceBranch
    def service_branches_for_pensions
      format_service_branches_for_pensions(map_service_episodes_to_branches)
    rescue => e
      Rails.logger.error("Error fetching service branches for Pension prefill: #{e}")
      {}
    end

    # @return [Hash] { army => true, navy => true, ... }
    # Filters out any unknown branches
    def format_service_branches_for_pensions(branches)
      branches.uniq.compact_blank.index_with { true }
    end

    ##
    # If the veteran began service after 1971, their service number is their SSN
    # We haven't identified a source for pre-1971 service numbers for prefill
    def service_number
      year_of_entry = first_uniformed_entry_date.to_i if first_uniformed_entry_date
      @user&.ssn_normalized if year_of_entry > 1971
    rescue => e
      Rails.logger.error("Error fetching service number for Pension prefill: #{e}")
      nil
    end

    private

    def map_service_episodes_to_branches
      service_history.episodes.map do |episode|
        branch = episode.branch_of_service
        branch_value = ClaimsApi::ServiceBranchMapper.new(branch).value
        PensionMilitaryInformation::PENSION_SERVICE_BRANCHES_MAPPING[branch_value]
      end
    end
  end
end
