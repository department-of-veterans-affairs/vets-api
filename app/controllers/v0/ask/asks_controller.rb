# frozen_string_literal: true

module V0
  module Ask
    class AsksController < ApplicationController
      skip_before_action :authenticate, only: :create
      skip_before_action :verify_authenticity_token

      def create
        return not_implemented unless Flipper.enabled?(:get_help_ask_form)

        request = SavedClaim::Ask.new(form: form_submission)

        # validate!(request)

        oracle_form = ::Ask::Iris::Oracle::OracleForm.new request.parsed_form

        confirmation_number = ::Ask::Iris::OracleRPAService.submit_form(oracle_form)

        render json: {
          'confirmationNumber': confirmation_number,
          'dateSubmitted': DateTime.now.utc.strftime('%m-%d-%Y')
        }, status: :created
      end

      private

      def not_implemented
        render nothing: true, status: :not_implemented, as: :json
      end

      def form_submission
        params.require(:inquiry).require(:form)
      rescue
        raise
      end

      def validate!(request)
        raise Common::Exceptions::ValidationErrors, request unless request.valid?
      end
    end
  end
end
