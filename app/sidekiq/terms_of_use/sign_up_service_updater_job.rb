# frozen_string_literal: true

require 'map/sign_up/service'
require 'sidekiq/attr_package'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Job

    sidekiq_options retry: 5 # ~17 mins

    sidekiq_retries_exhausted do |job, exception|
      Rails.logger.warn(
        "[TermsOfUse][SignUpServiceUpdaterJob] Retries exhausted for #{job['class']} " \
        "with args #{job['args']}: #{exception.message}"
      )
    end

    attr_reader :icn, :signature_name, :version

    def perform(attr_package_key)
      raise 'test'
      attrs = Sidekiq::AttrPackage.find(attr_package_key)

      @icn = attrs[:icn]
      @signature_name = attrs[:signature_name]
      @version = attrs[:version]

      terms_of_use_agreement.accepted? ? accept : decline

      Sidekiq::AttrPackage.delete(attr_package_key)
    end

    private

    def accept
      MAP::SignUp::Service.new.agreements_accept(icn:, signature_name:, version:)
    end

    def decline
      MAP::SignUp::Service.new.agreements_decline(icn:)
    end

    def terms_of_use_agreement
      UserAccount.find_by(icn:).terms_of_use_agreements.where(agreement_version: version).last
    end
  end
end
