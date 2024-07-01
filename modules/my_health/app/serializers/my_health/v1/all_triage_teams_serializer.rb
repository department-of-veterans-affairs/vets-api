# frozen_string_literal: true

module MyHealth
  module V1
    class AllTriageTeamsSerializer
      include JSONAPI::Serializer

      set_type :all_triage_teams
      set_id :triage_team_id

      attributes :triage_team_id, :name, :station_number,
                 :blocked_status, :preferred_team, :relationship_type
    end
  end
end
