# frozen_string_literal: true

module SignIn
  module Webauthn
    class RegistrationsController < ApplicationController
      protect_from_forgery with: :exception
      before_action :set_user
      after_action  :set_csrf_header

      def options
        options, challenge_id = Registration::OptionsGenerator.new(@user_verification).perform

        render json: { options:, challenge_id: }, status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def verify
        verified = Registration::Verifier.new(@user_verification, registration_params, challenge_id).perform

        render json: { verified: }, status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_user
        @user_verification = current_user.user_verification
        @user_account = @user_verification.user_account
      end

      def registration_params
        params.require(:registration)
      end

      def challenge_id
        params.require(:challenge_id)
      end
    end
  end
end
