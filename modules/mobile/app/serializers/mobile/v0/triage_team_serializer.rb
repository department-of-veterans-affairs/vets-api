# frozen_string_literal: true

module Mobile
  module V0
    class TriageTeamSerializer < ActiveModel::Serializer
      def id
        object.triage_team_id
      end

      attribute :triage_team_id
      attribute :name
      attribute :relation_type
      attribute :preferred_team
    end
  end
end
