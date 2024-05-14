# frozen_string_literal: true

require 'map/sign_up/service'
require 'sidekiq/attr_package'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Job

    sidekiq_options retry_for: 47.hours

    sidekiq_retries_exhausted do |job, exception|
      attr_package_key = job['args'].first
      attrs = Sidekiq::AttrPackage.find(attr_package_key)

      Rails.logger.warn('[TermsOfUse][SignUpServiceUpdaterJob] retries exhausted',
                        { icn: attrs[:icn], exception_message: exception.message, attr_package_key: })
    end

    attr_reader :icn, :signature_name, :version

    def perform(attr_package_key)
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
