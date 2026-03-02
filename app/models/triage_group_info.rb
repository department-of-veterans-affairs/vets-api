# frozen_string_literal: true

require 'vets/model'

##
# Lightweight model representing an embedded triage group (provider recipient)
# returned inline with a message response from MHV Secure Messaging API.
#
# @!attribute triage_team_id
#   @return [Integer]
# @!attribute name
#   @return [String]
# @!attribute preferred_team
#   @return [Boolean]
# @!attribute active
#   @return [Boolean]
# @!attribute station_number
#   @return [String]
# @!attribute relation_type
#   @return [String]
# @!attribute oh_triage_group
#   @return [Boolean]
#
class TriageGroupInfo
  include Vets::Model

  attribute :triage_team_id, Integer
  attribute :name, String
  attribute :preferred_team, Bool, default: false
  attribute :active, Bool, default: true
  attribute :station_number, String
  attribute :health_care_system_name, String
  attribute :location_name, String
  attribute :location_station_number, String
  attribute :group_type_enum_val, String
  attribute :sub_group_type_enum_val, String
  attribute :group_type_patient_display, String
  attribute :sub_group_type_patient_display, String
  attribute :team_name, String
  attribute :lead_provider_name, String
  attribute :suggested_name_display, String
  attribute :description, String
  attribute :legacy_name, String
  attribute :oh_pool_id, String
  attribute :oplock, Integer
  attribute :created_date, Vets::Type::UTCTime
  attribute :modified_date, Vets::Type::UTCTime
  attribute :relation_type, String
  attribute :oh_triage_group, Bool, default: false
end
