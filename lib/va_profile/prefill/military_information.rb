require 'hca/military_information'

module VAProfile
  module Prefill
    class MilitaryInformation < HCA::MilitaryInformation
      PREFILL_METHODS = %i[
        last_service_branch
        currently_active_duty
        currently_active_duty_hash
        tours_of_duty                                # Started by TT1
        is_va_service_connected
        compensable_va_service_connected
        service_branches                             # started by TT1
        va_compensation_type
        service_periods
        guard_reserve_service_history
        latest_guard_reserve_service_period
      ].freeze  # map all of these to VAProfile.

      # initialize (and other methods) inherited from HCA::MilitaryInformation

      def service_branches
        military_service_episodes.map(&:branch_of_service_code).uniq
      end
  
      # @return [Array<Hash>] Data about the veteran's tours of duty
      #  including service branch served under and date range of each tour
      def tours_of_duty
        military_service_episodes.map do |military_service_episode|
          {
            service_branch: military_service_episode.branch_of_service,
            date_range: {
              from: military_service_episode.begin_date.to_s,
              to: military_service_episode.end_date.to_s
            }
          }
        end
      end      
    end
  end
end
