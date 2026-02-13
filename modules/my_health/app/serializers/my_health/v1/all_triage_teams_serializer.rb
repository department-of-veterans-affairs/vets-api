# frozen_string_literal: true

module MyHealth
  module V1
    class AllTriageTeamsSerializer
      include JSONAPI::Serializer

      set_type :all_triage_teams
      set_id :triage_team_id

      attributes :triage_team_id, :name, :station_number,
                 :blocked_status, :preferred_team, :relation_type, :lead_provider_name,
                 :location_name, :team_name, :suggested_name_display, :health_care_system_name,
                 :group_type_enum_val, :sub_group_type_enum_val, :group_type_patient_display,
                 :sub_group_type_patient_display, :oh_triage_group, :migrating_to_oh
    end
  end
end
