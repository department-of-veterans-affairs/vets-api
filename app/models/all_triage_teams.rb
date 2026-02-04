# frozen_string_literal: true

require 'vets/model'

# AllTriageTeams model
class AllTriageTeams
  include Vets::Model
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  attribute :triage_team_id, Integer
  attribute :name, String
  attribute :station_number, String
  attribute :blocked_status, Bool, default: false
  attribute :preferred_team, Bool, default: false
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
  attribute :oh_triage_group, Bool, default: false
  attribute :migrating_to_oh, Bool, default: false

  default_sort_by name: :asc
end
