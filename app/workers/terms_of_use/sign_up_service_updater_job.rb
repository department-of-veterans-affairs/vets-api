# frozen_string_literal: true

require 'mobile_application_platform/sign_up/service'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Worker

    sidekiq_options retry: 15 # 2.1 days using exponential backoff

    sidekiq_retries_exhausted do |job, exception|
      Rails.logger.warn(
        "[TermsOfUse][SignUpServiceUpdaterJob] Retries exhausted for #{job['name']} " \
        "with args #{job['args']}: #{exception.message}"
      )
    end

    attr_reader :terms_of_use_agreement, :signature_name

    def perform(terms_of_use_agreement_id, signature_name)
      @terms_of_use_agreement = TermsOfUseAgreement.find(terms_of_use_agreement_id)
      @signature_name = signature_name
      terms_of_use_agreement.accepted? ? accept : decline
    end

    private

    def accept
      MobileApplicationPlatform::SignUp::Service.new.agreements_accept(icn:, signature_name:, version:)
    end

    def decline
      MobileApplicationPlatform::SignUp::Service.new.agreements_decline(icn:)
    end

    def icn
      @icn ||= terms_of_use_agreement.user_account.icn
    end

    def version
      @version ||= terms_of_use_agreement.agreement_version
    end
  end
end
