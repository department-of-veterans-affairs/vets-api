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
        params.require(:pre_need_request).permit!
      end
    end
  end
end
