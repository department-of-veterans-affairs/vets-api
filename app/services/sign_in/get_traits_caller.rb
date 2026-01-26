# frozen_string_literal: true

module SignIn
  class GetTraitsCaller
    def initialize(user_attributes)
      @user_attributes = user_attributes
    end

    def perform_async
      return unless credential_uuid && credential_email
      return unless credential_method

      cache_key = create_cache_key

      Identity::GetSSOeTraitsByCspidJob.perform_async(
        cache_key,
        credential_method,
        credential_uuid
      )
    rescue => e
      Rails.logger.warn(
        '[SignInService] SSOe get traits lookup failed',
        error: e.class.name,
        message: e.message,
        credential_uuid:
      )

      StatsD.increment('api.ssoe.traits.failure')
      nil
    end

    private

    attr_reader :user_attributes

    def credential_method
      return 'idme' if idme_uuid

      'logingov' if logingov_uuid
    end

    def create_cache_key
      Sidekiq::AttrPackage.create(
        expires_in: 7.days,
        first_name:,
        last_name:,
        birth_date:,
        ssn:,
        email: credential_email,
        phone: nil,
        street1: address[:street1],
        city: address[:city],
        state: address[:state],
        zipcode: address[:zipcode]
      )
    end

    def credential_uuid        = idme_uuid || logingov_uuid
    def credential_email       = user_attributes[:csp_email]
    def idme_uuid              = user_attributes[:idme_uuid]
    def logingov_uuid          = user_attributes[:logingov_uuid]
    def first_name             = user_attributes[:first_name]
    def last_name              = user_attributes[:last_name]
    def birth_date             = user_attributes[:birth_date]
    def ssn                    = user_attributes[:ssn]
    def address                = user_attributes[:address]
  end
end
