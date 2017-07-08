# frozen_string_literal: true
module V0
  module Preneeds
    class ApplicationFormsController < PreneedsController
      REDIS_EACH_TTL = REDIS_CONFIG['preneeds_store']['each_ttl']

      def new
      end

      def create
        application_form = ::Preneeds::ApplicationForm.new(application_form_params)
        raise Common::Exceptions::ValidationErrors, application_form unless application_form.valid?

        resource = client.receive_pre_need_application(application_form.message)
        render json: resource, serializer: ReceiveApplicationSerializer
      end

      private

      def application_form_params
        params.require(:pre_need_request)
              .permit(
                :application_status, :has_attachments, :has_currently_buried, :sending_code,
                applicant: ::Preneeds::Applicant.permitted_params,
                claimant: ::Preneeds::Claimant.permitted_params,
                currently_buried_persons: [::Preneeds::CurrentlyBuried.permitted_params],
                veteran: ::Preneeds::Veteran.permitted_params
              )
      end
    end
  end
end
