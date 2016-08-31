module HealthcareMessaging
  module V1
    class TriageTeamsController < HealthcareMessagingController
      def index
        teams = client.get_triage_teams
        render json: teams.data,
               serializer: CollectionSerializer,
               each_serializer: TriageTeamSerializer,
               meta: teams.metadata
      end
    end
  end
end
