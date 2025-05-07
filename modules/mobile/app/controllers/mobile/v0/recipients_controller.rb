# frozen_string_literal: true

module Mobile
  module V0
    class RecipientsController < MessagingController
      def recipients
        resource = client.get_triage_teams(@current_user.uuid, use_cache?)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource = resource.order(params[:sort]) if params[:sort].present?

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        json = TriageTeamSerializer.new(resource.records).serializable_hash.merge(options)
        render json:
      end

      def all_recipients
        resource = client.get_all_triage_teams(@current_user.uuid, use_cache?)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource = resource.order(params[:sort]) if params[:sort].present?

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        json = AllTriageTeamsSerializer.new(resource.records).serializable_hash.merge(options)
        render json:
      end
    end
  end
end
