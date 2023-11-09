# frozen_string_literal: true

require 'common/models/base'

# AllTriageTeams model
class AllTriageTeams < Common::Base
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :triage_team_id, Integer
  attribute :name, String, sortable: { order: 'ASC', default: true }
  attribute :station_number, String
  attribute :blocked_status, Boolean
  attribute :preferred_team, Boolean
  attribute :relationship_type, String

  def <=>(other)
    name <=> other.name
  end
end
