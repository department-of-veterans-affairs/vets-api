# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module PhaseDatesSerializer
          def self.serialize(phase_dates)
            {
              'phaseChangeDate' => phase_dates.phase_change_date,
              'currentPhaseBack' => phase_dates.current_phase_back,
              'phaseType' => phase_dates.phase_type,
              'latestPhaseType' => phase_dates.latest_phase_type,
              'previousPhases' => phase_dates.previous_phases
            }
          end
        end
      end
    end
  end
end
