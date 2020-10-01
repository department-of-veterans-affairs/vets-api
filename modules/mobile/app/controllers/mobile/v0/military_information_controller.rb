# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class MilitaryInformationController < ApplicationController
      def get_service_history
        render json: Mobile::V0::MilitaryInformationSerializer.new(@current_user)
      end
    end
  end
end
