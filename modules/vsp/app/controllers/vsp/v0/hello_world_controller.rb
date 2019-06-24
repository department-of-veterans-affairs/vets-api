# frozen_string_literal: true

module Vsp
  module V0
    class HelloWorldController < ApplicationController
      skip_before_action :authenticate

      def index
        message = service.get_message
        render json: Vsp::MessageSerializer.new(message).serialized_json
      end

      private

      def service
        Vsp::Service.new
      end
    end
  end
end
