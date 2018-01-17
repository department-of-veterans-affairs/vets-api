# frozen_string_literal: true

class TriageTeamSerializer < ActiveModel::Serializer
  def id
    object.triage_team_id
  end

  attribute :triage_team_id
  attribute :name
  attribute :relation_type
end
