# frozen_string_literal: true

class TriageTeamSerializer
  include JSONAPI::Serializer

  set_id :triage_team_id
  set_type :triage_teams

  attribute :triage_team_id
  attribute :name
  attribute :relation_type
  attribute :preferred_team
end
