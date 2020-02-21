# frozen_string_literal: true

module V0
  module MDOT
    class SuppliesController < ApplicationController
      def index
        supplies = client.get_supplies
        render json: supplies.body
      end

      private

      def client
        MDOT::Client.new(@current_user)
      end
    end
  end
end
