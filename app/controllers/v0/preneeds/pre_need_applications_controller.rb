# frozen_string_literal: true
module V0
  module Preneeds
    class PreNeedApplicationsController < PreneedsController
      def create
        pre_need_application = FactoryGirl.build :application_input
        raise Common::Exceptions::ValidationErrors, pre_need_application unless pre_need_application.valid?

        resource = client.receive_pre_need_application(pre_need_application.message)
        render json: resource.data
      end
    end
  end
end
