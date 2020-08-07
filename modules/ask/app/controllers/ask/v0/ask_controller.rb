# frozen_string_literal: true

module Ask
  module V0
    class AskController < ApplicationController
      skip_before_action :authenticate

      def index
        message = service.get_message
        render json: AskSerializer.new(message).serialized_json
      end

      private

      def service
        Service.new
      end
    end
  end
end
