# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class TriageTeamAdapter
        # Filter out triage teams with blocked_status=true
        # @param teams [Array] Array of AllTriageTeams objects
        # @return [Array] Filtered array with only non-blocked teams
        def self.filter_blocked_teams(teams)
          teams.reject(&:blocked_status)
        end
      end
    end
  end
end
