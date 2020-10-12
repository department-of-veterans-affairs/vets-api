# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'

module Mobile
  module V0
    class LettersController < ApplicationController
      before_action { authorize :evss, :access? }

      def letters
        service_response = EVSS::Letters::Service.new(@current_user).get_letters
        response_template = OpenStruct.new
        response_template.id = @current_user.uuid
        response_template.letters = service_response.letters
        response_template.full_name = service_response.full_name
        render json: Mobile::V0::LettersSerializer.new(response_template)
      end
    end
  end
end
