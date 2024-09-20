# frozen_string_literal: true

require 'mhv/account_creation/service'

module MHV
  module UserAccount
    class Creator
      attr_reader :user_verification, :break_cache

      def initialize(user_verification:, break_cache: false)
        @user_verification = user_verification
        @break_cache = break_cache
      end

      def perform
        validate!
        create_mhv_user_account!
      rescue ActiveModel::ValidationError, Errors::ValidationError => e
        log_and_raise_error(e, :validation)
      rescue Common::Client::Errors::Error => e
        log_and_raise_error(e, :client)
      rescue => e
        log_and_raise_error(e, :creator)
      end

      private

      def create_mhv_user_account!
        account = MHVUserAccount.new(mhv_account_creation_response)
        account.validate!

        account
      end

      def mhv_account_creation_response
        tou_occurred_at = current_tou_agreement.created_at

        mhv_client.create_account(icn:, email:, tou_occurred_at:, break_cache:)
      end

      def icn
        @icn ||= user_account.icn
      end

      def email
        @email ||= user_verification.user_credential_email&.credential_email
      end

      def current_tou_agreement
        @current_tou_agreement ||= user_account.terms_of_use_agreements.current.last
      end

      def user_account
        @user_account ||= user_verification.user_account
      end

      def mhv_client
        MHV::AccountCreation::Service.new
      end

      def validate!
        errors = [
          ('ICN must be present' if icn.blank?),
          ('Email must be present' if email.blank?),
          ('Current terms of use agreement must be present' if current_tou_agreement.blank?),
          ("Current terms of use agreement must be 'accepted'" unless current_tou_agreement&.accepted?)
        ].compact

        raise Errors::ValidationError, errors.join(', ') if errors.present?
      end

      def log_and_raise_error(error, type = nil)
        klass = case type
                when :validation
                  Errors::ValidationError
                when :client
                  Errors::MHVClientError
                else
                  Errors::CreatorError
                end

        Rails.logger.error("[MHV][UserAccount][Creator] #{type} error", error_message: error.message, icn:)
        raise klass, error.message
      end
    end
  end
end
