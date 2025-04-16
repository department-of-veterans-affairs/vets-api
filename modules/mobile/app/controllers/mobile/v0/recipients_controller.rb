# frozen_string_literal: true

module Mobile
  module V0
    class RecipientsController < MessagingController
      def recipients
        resource = client.get_triage_teams(@current_user.uuid, use_cache? || true)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource = resource.sort(params[:sort])

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        render json: TriageTeamSerializer.new(resource.data, options)
      end

      def all_recipients
        resource = client.get_all_triage_teams(@current_user.uuid, use_cache? || true)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource = resource.sort(params[:sort])

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        render json: AllTriageTeamsSerializer.new(resource.data, options)
      end
    end
  end
end
