# frozen_string_literal: true

module TermsOfUse
  class Acceptor
    def initialize(user_account:, version:)
      @user_account = user_account
      @version = version
    end

    def perform!
      terms_of_use_agreement.accepted!
      update_sign_up_service
      Logger.new(terms_of_use_agreement:).perform

      terms_of_use_agreement
    end

    private

    attr_reader :user_account, :version

    def terms_of_use_agreement
      @terms_of_use_agreement ||= user_account.terms_of_use_agreements.new(agreement_version: version)
    end

    def update_sign_up_service
      SignUpServiceUpdaterJob.perform_async(terms_of_use_agreement.id)
    end
  end
end
