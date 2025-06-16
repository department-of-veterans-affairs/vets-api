# frozen_string_literal: true

require 'vets/model'

# TriageTeam model
class TriageTeam
  include Vets::Model
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :triage_team_id, Integer
  attribute :name, String
  attribute :relation_type, String
  attribute :preferred_team, Bool, default: false

  default_sort_by name: :asc
end
