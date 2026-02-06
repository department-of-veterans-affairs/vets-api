# frozen_string_literal: true

require 'vets/model'

# Lightweight model for caching minimal triage team data
# Contains only triage_team_id and station_number to reduce storage
class TriageTeamCache
  include Vets::Model
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :triage_team_id, Integer
  attribute :station_number, String
end
