# frozen_string_literal: true
module V0
  module Preneeds
    class PreNeedApplicationsController < PreneedsController
      def create
        pre_need_application = ::Preneeds::ApplicationInput.new(preneeds_application_params)
        raise Common::Exceptions::ValidationErrors, pre_need_application unless pre_need_application.valid?

        resource = client.receive_pre_need_application(pre_need_application.message)
        render json: resource, serializer: ReceiveApplicationSerializer
      end

      private

      def preneeds_application_params
        params.require(:pre_need_request)
              .permit(
                :application_status, :has_attachments, :has_currently_buried, :sending_code,
                applicant: ::Preneeds::ApplicantInput.permitted_params,
                claimant: ::Preneeds::ClaimantInput.permitted_params,
                currently_buried_persons: [::Preneeds::CurrentlyBuriedInput.permitted_params],
                veteran: ::Preneeds::VeteranInput.permitted_params
              )
      end
    end
  end
end
