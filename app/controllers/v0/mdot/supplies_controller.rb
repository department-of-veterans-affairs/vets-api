# frozen_string_literal: true

module V0
  module MDOT
    class SuppliesController < ApplicationController
      before_action { authorize :mdot, :access? }

      def create
        response = client.submit_order(request.raw_post)
        render json: response.body
      end

      private

      def client
        ::MDOT::Client.new(@current_user)
      end
    end
  end
end