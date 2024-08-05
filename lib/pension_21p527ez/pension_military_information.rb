# frozen_string_literal: true

require 'va_profile/prefill/military_information'
require 'claims_api/service_branch_mapper'

module Pension21p527ez
  class PensionFormMilitaryInformation < FormMilitaryInformation
    include Virtus.model

    attribute :first_uniformed_entry_date, String
    attribute :last_active_discharge_date, String
    attribute :service_branches_for_pensions, Hash
    attribute :service_number, String
  end

  class PensionMilitaryInformation < VAProfile::Prefill::MilitaryInformation
    PREFILL_METHODS = %w[
      currently_active_duty
      currently_active_duty_hash
      discharge_type
      first_uniformed_entry_date
      guard_reserve_service_history
      hca_last_service_branch
      last_discharge_date
      last_active_discharge_date
      last_entry_date
      last_service_branch
      latest_guard_reserve_service_period
      post_nov111998_combat
      service_branches
      service_branches_for_pensions
      service_episodes_by_date
      service_number
      service_periods
      sw_asia_combat
      tours_of_duty
    ].freeze

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

    def first_uniformed_entry_date
      service_history.uniformed_service_initial_entry_date
    end

    def last_active_discharge_date
      service_history.release_from_active_duty_date
    end

    def service_branches_for_pensions
      branches = {}
      service_history.episodes.map(&:branch_of_service).uniq.each do |branch|
        branch_value = ClaimsApi::ServiceBranchMapper.new(branch).value
        pension_branch = PENSION_SERVICE_BRANCHES_MAPPING[branch_value]
        branches[pension_branch] = true if pension_branch
      end
      branches
    rescue => e
      Rails.logger.error("Error fetching service branches for Pension prefill: #{e}")
      {}
    end

    def service_number
      year_of_entry = first_uniformed_entry_date.to_i if first_uniformed_entry_date
      @user.ssn_normalized if year_of_entry > 1971
    rescue => e
      Rails.logger.error("Error fetching service number for Pension prefill: #{e}")
      nil
    end
  end
end
