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
  attribute :relation_type, String
  attribute :lead_provider_name, String
  attribute :location_name, String
  attribute :lead_provider_name, String
  attribute :team_name, String
  attribute :suggested_name_display, String
  attribute :health_care_system_name, String
  attribute :group_type_enum_val, String
  attribute :sub_group_type_enum_val, String
  attribute :group_type_patient_display, String
  attribute :sub_group_type_patient_display, String

  def <=>(other)
    name <=> other.name
  end
end
