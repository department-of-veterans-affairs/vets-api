# frozen_string_literal: true
module V0
  class TriageTeamsController < SMController
    def index
      teams = client.get_triage_teams

      render json: teams.data,
             serializer: CollectionSerializer,
             each_serializer: TriageTeamSerializer,
             meta: teams.metadata
    end
  end
end
