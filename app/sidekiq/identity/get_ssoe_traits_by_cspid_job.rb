# frozen_string_literal: true

require 'ostruct'

module Identity
  class GetSSOeTraitsByCspidJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 5.minutes

    def perform(cache_key)
      return if Settings.vsp_environment == 'production'

      user_attributes = Sidekiq::AttrPackage.find(cache_key)

      user_struct = OpenStruct.new(user_attributes)

      user = build_user(user_struct)
      address = build_address(user_struct)

      response = SSOe::Service.new.get_traits(
        credential_method: user_struct.identity.sign_in[:service_name],
        credential_id: user_struct.identity.uuid,
        user:,
        address:
      )

      log_response(response, user_struct)
    rescue => e
      handle_error(e)
    end

    private

    def build_user(user)
      SSOe::Models::User.new(
        first_name: user.first_name,
        last_name: user.last_name,
        birth_date: user.birth_date,
        ssn: user.ssn,
        email: user.email,
        phone: user.phone
      )
    end

    def build_address(user)
      SSOe::Models::Address.new(
        street1: user.address&.street,
        city: user.address&.city,
        state: user.address&.state,
        zipcode: user.address&.postal_code
      )
    end

    def log_response(response, user)
      if response[:icn].present?
        Rails.logger.info("[GetSSOeTraitsByCspidJob] Success for user #{user.uuid}, ICN: #{response[:icn]}")
        StatsD.increment('ssoe.traits_fetch.success')
      else
        Rails.logger.warn("[GetSSOeTraitsByCspidJob] Failure for user #{user.uuid}", response)
        StatsD.increment('ssoe.traits_fetch.failure')
      end
    end

    def handle_error(error)
      Rails.logger.error("[GetSSOeTraitsByCspidJob] Unexpected error: #{error.message}")
      StatsD.increment('ssoe.traits_fetch.unexpected_error')
    end
  end
end
