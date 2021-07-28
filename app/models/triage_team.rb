# frozen_string_literal: true

require 'common/models/base'

# TriageTeam model
class TriageTeam < Common::Base
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :triage_team_id, Integer
  attribute :name, String, sortable: { order: 'ASC', default: true }
  attribute :relation_type, String
  attribute :preferred_team, Boolean

  def <=>(other)
    name <=> other.name
  end
end
