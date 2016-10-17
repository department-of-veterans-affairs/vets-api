# frozen_string_literal: true
module V0
  class TriageTeamsController < SMController
    def index
      resource = client.get_triage_teams
      resource = resource.sort(params[:sort])

      raise Common::Exceptions::InternalServerError unless resource.present?

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: TriageTeamSerializer,
             meta: resource.metadata
    end
  end
end
