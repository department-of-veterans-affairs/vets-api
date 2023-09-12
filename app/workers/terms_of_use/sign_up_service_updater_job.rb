# frozen_string_literal: true

require 'mobile_application_platform/sign_up/service'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Worker

    attr_reader :terms_of_use_agreement

    def perform(terms_of_use_agreement_id)
      @terms_of_use_agreement = TermsOfUseAgreement.find(terms_of_use_agreement_id)

      terms_of_use_agreement.accepted? ? accept : decline
    end

    private

    def accept
      MobileApplicationPlatform::SignUp::Service.new.agreements_accept(icn:)
    end

    def decline
      MobileApplicationPlatform::SignUp::Service.new.agreements_decline(icn:)
    end

    def icn
      @icn ||= terms_of_use_agreement.user_account.icn
    end
  end
end
