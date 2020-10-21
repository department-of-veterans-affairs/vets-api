# frozen_string_literal: true

module V0
  module Ask
    class AsksController < ApplicationController
      skip_before_action :authenticate, only: :create

      def create
        return service_unavailable unless Flipper.enabled?(:get_help_ask_form)

        claim = SavedClaim::Ask.new(form: form_submission)

        validate!(claim)

        render json: {
          'confirmationNumber': '0000-0000-0000',
          'dateSubmitted': DateTime.now.utc.strftime('%m-%d-%Y')
        }
      end

      private

      def service_unavailable
        render nothing: true, status: :service_unavailable, as: :json
      end

      def form_submission
        params.require(:inquiry).require(:form)
      rescue
        raise
      end

      def validate!(claim)
        raise Common::Exceptions::ValidationErrors, claim unless claim.valid?
      end
    end
  end
end
