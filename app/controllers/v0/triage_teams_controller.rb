# frozen_string_literal: true

module V0
  class TriageTeamsController < SMController
    def index
      resource = client.get_triage_teams
      raise Common::Exceptions::InternalServerError if resource.blank?

      resource = resource.sort(params[:sort])

      # Even though this is a collection action we are not going to paginate
      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: TriageTeamSerializer,
             meta: resource.metadata
    end
  end
end
