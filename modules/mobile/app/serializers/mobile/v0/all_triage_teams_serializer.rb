# frozen_string_literal: true

module Mobile
  module V0
    class AllTriageTeamsSerializer
      include JSONAPI::Serializer

      set_type :all_triage_teams
      set_id(&:triage_team_id)

      attributes :triage_team_id, :name, :station_number, :relation_type,
                 :location_name, :suggested_name_display,
                 :health_care_system_name
    end
  end
end
