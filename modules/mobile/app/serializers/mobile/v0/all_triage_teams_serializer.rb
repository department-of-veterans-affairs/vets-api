# frozen_string_literal: true

module Mobile
  module V0
    class AllTriageTeamsSerializer
      include JSONAPI::Serializer

      set_type :all_triage_teams
      set_id(&:triage_team_id)

      attributes :triage_team_id,
                 :name,
                 :station_number,
                 :preferred_team,
                 :relation_type,
                 :location_name,
                 :suggested_name_display,
                 :health_care_system_name,
                 :oh_triage_group,
                 :migrating_to_oh
    end
  end
end
