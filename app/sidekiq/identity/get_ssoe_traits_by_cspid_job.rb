# frozen_string_literal: true

module Identity
  class GetSSOeTraitsByCspidJob
    include Sidekiq::Job

    sidekiq_options retry: 3, queue: :default

    def perform(cache_key, credential_method, credential_id)
      attributes = Sidekiq::AttrPackage.find(cache_key)

      unless attributes
        log_failure('Missing attributes in Redis for key', credential_method, credential_id)
        return
      end

      user = build_user(attributes)
      address = build_address(attributes)

      return unless validate_user(user, credential_method, credential_id)

      response = SSOe::Service.new.get_traits(credential_method:, credential_id:, user:, address:)

      if response[:success]
        log_success(response[:icn], credential_method, credential_id)
        StatsD.increment('get_ssoe_traits_by_cspid.success', tags: ["credential_method:#{credential_method}"])
        Sidekiq::AttrPackage.delete(cache_key)
      else
        log_failure('SSOe::Service.get_traits failed', credential_method, credential_id, response[:error])
        raise "SSOe::Service.get_traits failed - #{response[:error].inspect}"
      end
    rescue => e
      log_failure("Unhandled exception: #{e.class} - #{e.message}", credential_method, credential_id)
      raise
    end

    private

    def validate_user(user, credential_method, credential_id)
      unless user.valid?
        log_failure("Invalid user attributes: #{user.errors.full_messages.join(', ')}", credential_method,
                    credential_id)
        return false
      end
      true
    end

    def build_user(attrs)
      SSOe::Models::User.new(
        first_name: attrs[:first_name],
        last_name: attrs[:last_name],
        birth_date: attrs[:birth_date],
        ssn: attrs[:ssn],
        email: attrs[:email],
        phone: attrs[:phone]
      )
    end

    def build_address(attrs)
      SSOe::Models::Address.new(
        street1: attrs[:street1],
        city: attrs[:city],
        state: attrs[:state],
        zipcode: attrs[:zipcode]
      )
    end

    def log_success(icn, credential_method, credential_id)
      Rails.logger.info(
        '[GetSSOeTraitsByCspidJob] SSOe::Service.get_traits success',
        icn:,
        credential_method:,
        credential_id:
      )
    end

    def log_failure(message, credential_method, credential_id, error = nil)
      log_payload = {
        credential_method:,
        credential_id:
      }
      log_payload[:error] = error if error

      Rails.logger.error("[GetSSOeTraitsByCspidJob] #{message}", log_payload)
      StatsD.increment('get_ssoe_traits_by_cspid.failure', tags: ["credential_method:#{credential_method}"])
    end
  end
end
