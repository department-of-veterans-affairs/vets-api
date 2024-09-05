# frozen_string_literal: true

require 'terms_of_use/exceptions'
require 'sidekiq/attr_package'

module TermsOfUse
  class Acceptor
    include ActiveModel::Validations

    attr_reader :user_account, :icn, :version, :sync

    validates :user_account, :icn, :version, presence: true

    def initialize(user_account:, version:, sync: false)
      @user_account = user_account
      @version = version
      @sync = sync
      @icn = user_account&.icn

      validate!
    rescue ActiveModel::ValidationError => e
      log_and_raise_acceptor_error(e)
    end

    def perform!
      terms_of_use_agreement.accepted!

      update_sign_up_service
      Logger.new(terms_of_use_agreement:).perform

      terms_of_use_agreement
    rescue ActiveRecord::RecordInvalid, StandardError => e
      log_and_raise_acceptor_error(e)
    end

    private

    def terms_of_use_agreement
      @terms_of_use_agreement ||= user_account.terms_of_use_agreements.new(agreement_version: version)
    end

    def update_sign_up_service
      Rails.logger.info('[TermsOfUse] [Acceptor] update_sign_up_service', { icn: })
      SignUpServiceUpdaterJob.set(sync:).perform_async(user_account.id, version)
    end

    def log_and_raise_acceptor_error(error)
      Rails.logger.error("[TermsOfUse] [Acceptor] Error: #{error.message}", { user_account_id: user_account&.id })
      raise Errors::AcceptorError, error.message
    end
  end
end
