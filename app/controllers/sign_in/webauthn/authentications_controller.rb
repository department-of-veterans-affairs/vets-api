# frozen_string_literal: true

module SignIn
  module Webauthn
    class AuthenticationsController < ApplicationController
      skip_before_action :authenticate
      after_action :set_csrf_header

      def options
        options, challenge_id =
          Authentication::OptionsGenerator.new(credential_email:).perform

        render json: { options:, challenge_id: }, status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def verify
        session_container = Authentication::Verifier.new(authentication_params[:attest], challenge_id).perform

        response_body = TokenSerializer.new(session_container:, cookies:).perform
        response_body[:verified] = true

        render json: response_body, status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def credential_email
        params[:credential_email].to_s.strip.downcase.presence
      end

      def authentication_params
        params.require(:authentication)
      end

      def challenge_id
        params.require(:challenge_id)
      end
    end
  end
end
