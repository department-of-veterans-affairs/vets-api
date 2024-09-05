# frozen_string_literal: true

module MyHealth
  module V1
    class TriageTeamsController < SMController
      def index
        resource = client.get_triage_teams(@current_user.uuid, use_cache?)
        if resource.blank?
          raise Common::Exceptions::RecordNotFound,
                "Triage teams for user ID #{@current_user.uuid} not found"
        end

        resource = resource.sort(params.permit(:sort)[:sort])

        # Even though this is a collection action we are not going to paginate
        render json: TriageTeamSerializer.new(resource.data, { meta: resource.metadata })
      end
    end
  end
end
