# frozen_string_literal: true

module MyHealth
  module V1
    class AllTriageTeamsController < SMController
      def index
        requires_oh = params[:requires_oh].try(:to_s)
        resource = client.get_all_triage_teams(@current_user.uuid, use_cache?, requires_oh)
        if resource.blank?
          raise Common::Exceptions::RecordNotFound,
                "Triage teams for user ID #{@current_user.uuid} not found"
        end

        resource = resource.order(params.permit(:sort)[:sort]) if params[:sort].present?

        # Even though this is a collection action we are not going to paginate
        render json: AllTriageTeamsSerializer.new(resource.records, { meta: resource.metadata })
      end
    end
  end
end
