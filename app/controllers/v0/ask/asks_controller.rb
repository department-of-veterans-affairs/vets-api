# frozen_string_literal: true

module V0
  module Ask
    class AsksController < ApplicationController
      skip_before_action :authenticate, only: :create
      skip_before_action :verify_authenticity_token

      def create
        return service_unavailable unless Flipper.enabled?(:get_help_ask_form)

        claim = SavedClaim::Ask.new(form: form_submission)

        if claim.valid?
          render json: { 'message': '200 ok' }
        else
          raise Common::Exceptions::ValidationErrors, claim
        end
      end

      private

      def service_unavailable
        render nothing: true, status: :service_unavailable, as: :json
      end
    end
  end
end
