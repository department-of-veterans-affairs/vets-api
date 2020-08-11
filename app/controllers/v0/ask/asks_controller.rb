# frozen_string_literal: true

module V0
  module Ask
    class AsksController < ApplicationController
      skip_before_action :authenticate, only: :create

      def create
        return service_unavailable unless Flipper.enabled?(:get_help_ask_form)

        render json: { 'message': '200 ok' }
      end

      private

      def service_unavailable
        render nothing: true, status: :service_unavailable, as: :json
      end
    end
  end
end
