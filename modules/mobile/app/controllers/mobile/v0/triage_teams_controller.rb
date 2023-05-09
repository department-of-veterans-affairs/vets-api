# frozen_string_literal: true

module Mobile
  module V0
    class TriageTeamsController < MessagingController
      def index
        resource = client.get_triage_teams(@current_user.uuid, use_cache? || true)
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
end
