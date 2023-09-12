# frozen_string_literal: true

module TermsOfUse
  class Logger
    STATSD_PREFIX = 'api.terms_of_use_agreements'

    def initialize(terms_of_use_agreement:)
      @terms_of_use_agreement = terms_of_use_agreement
    end

    def perform
      log_terms_of_use_agreement
      increment_terms_of_use_agreement_statsd
    end

    private

    attr_reader :terms_of_use_agreement

    def log_terms_of_use_agreement
      Rails.logger.info("[TermsOfUseAgreement] [#{prefix.capitalize}]", context)
    end

    def increment_terms_of_use_agreement_statsd
      StatsD.increment("#{STATSD_PREFIX}.#{prefix}",
                       tags: ["version:#{terms_of_use_agreement.agreement_version}"])
    end

    def prefix
      @prefix ||= terms_of_use_agreement.response
    end

    def context
      @context ||= {
        terms_of_use_agreement_id: terms_of_use_agreement.id,
        user_account_uuid: user_account.id,
        icn: user_account.icn,
        agreement_version: terms_of_use_agreement.agreement_version,
        response: terms_of_use_agreement.response
      }
    end

    def user_account
      @user_account ||= terms_of_use_agreement.user_account
    end
  end
end
