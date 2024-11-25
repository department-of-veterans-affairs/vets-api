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
        log_error(e, :validation)
        raise Errors::ValidationError, e.message
      rescue Common::Client::Errors::Error => e
        log_error(e, :client)

        raise Errors::MHVClientError.new(e.message, e.body)
      rescue => e
        log_error(e, :creator)
        raise Errors::CreatorError, e.message
      end

      private

      def create_mhv_user_account!
        account = MHVUserAccount.new(mhv_account_creation_response)
        account.validate!
        MPIData.find(icn)&.destroy
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

      def log_error(error, type)
        Rails.logger.error("[MHV][UserAccount][Creator] #{type} error", error_message: error.message, icn:)
      end
    end
  end
end
