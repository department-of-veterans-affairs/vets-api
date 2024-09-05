# frozen_string_literal: true

module MyHealth
  module V1
    class TriageTeamSerializer
      include JSONAPI::Serializer

      set_type :triage_teams
      set_id :triage_team_id
      attributes :triage_team_id, :name, :relation_type, :preferred_team
    end
  end
end
