# frozen_string_literal: true

module V0
  module MDOT
    class SuppliesController < ApplicationController
      before_action { authorize :mdot, :access? }

      def index
        supplies = client.get_supplies
        render json: supplies.body
      end

      private

      def client
        ::MDOT::Client.new(@current_user)
      end
    end
  end
end
