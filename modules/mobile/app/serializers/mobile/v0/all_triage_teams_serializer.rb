# frozen_string_literal: true

module Mobile
  module V0
    class AllTriageTeamsSerializer
      include JSONAPI::Serializer

      set_type :all_triage_teams
      set_id(&:triage_team_id)

      attributes :triage_team_id, :name, :relation_type, :preferred_team,
                 :station_number, :blocked_status
    end
  end
end
