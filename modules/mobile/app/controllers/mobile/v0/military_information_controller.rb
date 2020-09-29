# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class MilitaryInformationController < ApplicationController
      def get_service_history
        service_history = EMISRedis::MilitaryInformation.for_user(@current_user).service_history.map{|item| OpenStruct.new(item)}
        response_template = OpenStruct.new
        response_template.id = @current_user.uuid
        response_template.service_history = service_history
        render json: Mobile::V0::MilitaryInformationSerializer.new(response_template)
      end
    end
  end
end
