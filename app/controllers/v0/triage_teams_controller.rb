# frozen_string_literal: true

module V0
  class TriageTeamsController < SMController
    # is this controller used at all?
    def index
      resource = client.get_triage_teams(@current_user.uuid, use_cache? || true)
      raise Common::Exceptions::InternalServerError if resource.blank?

      resource = resource.sort(params[:sort])

      # Even though this is a collection action we are not going to paginate
      options = { meta: resource.metadata }
      render json: TriageTeamSerializer.new(resource.data, options)
    end
  end
end
