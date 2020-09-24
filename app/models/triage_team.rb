# frozen_string_literal: true

require 'common/models/base'

# TriageTeam model
class TriageTeam < Common::Base
  attribute :triage_team_id, Integer
  attribute :name, String, sortable: { order: 'ASC', default: true }
  attribute :relation_type, String

  def <=>(other)
    name <=> other.name
  end
end
