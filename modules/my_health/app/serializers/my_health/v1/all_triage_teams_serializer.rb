# frozen_string_literal: true

module MyHealth
  module V1
    class AllTriageTeamsSerializer < ActiveModel::Serializer
      def id
        object.triage_team_id
      end

      attribute :triage_team_id
      attribute :name
      attribute :station_number
      attribute :blocked_status
      attribute :preferred_team
      attribute :relationship_type
    end
  end
end
