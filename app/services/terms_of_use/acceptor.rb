# frozen_string_literal: true

require 'terms_of_use/exceptions'

module TermsOfUse
  class Acceptor
    include ActiveModel::Validations

    attr_reader :user_account, :icn, :common_name, :version, :async

    validates :user_account, :icn, :common_name, :version, presence: true

    def initialize(user_account:, common_name:, version:, async: true)
      @user_account = user_account
      @common_name = common_name
      @version = version
      @async = async
      @icn = user_account&.icn

      validate!
    rescue ActiveModel::ValidationError => e
      log_and_raise_acceptor_error(e)
    end

    def perform!
      if async
        asynchronous_update
      else
        synchronous_update
      end

      Logger.new(terms_of_use_agreement:).perform

      terms_of_use_agreement
    rescue ActiveRecord::RecordInvalid, StandardError => e
      log_and_raise_acceptor_error(e)
    end

    private

    def terms_of_use_agreement
      @terms_of_use_agreement ||= user_account.terms_of_use_agreements.new(agreement_version: version)
    end

    def asynchronous_update
      terms_of_use_agreement.accepted!
      SignUpServiceUpdaterJob.perform_async(attr_package_key)
    end

    def synchronous_update
      terms_of_use_agreement.accepted!
      SignUpServiceUpdaterJob.new.perform(attr_package_key)
    end

    def log_and_raise_acceptor_error(error)
      Rails.logger.error("[TermsOfUse] [Acceptor] Error: #{error.message}", { user_account_id: user_account&.id })
      raise Errors::AcceptorError, error.message
    end

    def attr_package_key
      Sidekiq::AttrPackage.create(icn:, signature_name: common_name, version:, expires_in: 2.days)
    end
  end
end
