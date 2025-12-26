# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module PhaseDatesBuilder
          def self.build(phase_dates_data)
            return nil if phase_dates_data.nil?

            BenefitsClaims::Responses::ClaimPhaseDates.new(
              phase_change_date: phase_dates_data['phaseChangeDate'],
              current_phase_back: phase_dates_data['currentPhaseBack'],
              phase_type: phase_dates_data['phaseType'],
              latest_phase_type: phase_dates_data['latestPhaseType'],
              previous_phases: phase_dates_data['previousPhases']
            )
          end
        end
      end
    end
  end
end
