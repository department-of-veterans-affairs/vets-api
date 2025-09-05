# frozen_string_literal: true

module Identity
  class GetSSOeTraitsByCspidJob
    include Sidekiq::Job

    sidekiq_options retry: 3, queue: :default

    def perform(cache_key, credential_method, credential_id)
      attributes = Sidekiq::AttrPackage.find(cache_key)

      unless attributes
        log_failure("Missing attributes in Redis for key: #{cache_key}", cache_key)
        return
      end

      user = build_user(attributes)
      address = build_address(attributes)

      return unless validate_user(user, cache_key)

      response = SSOe::Service.new.get_traits(credential_method:, credential_id:, user:, address:)

      if response[:success]
        log_success("SSOe::Service.get_traits success - ICN: #{response[:icn]}", cache_key)
      else
        log_failure("SSOe::Service.get_traits failed - #{response[:error].inspect}", cache_key)
      end
    rescue => e
      log_failure("Unhandled exception: #{e.class} - #{e.message}", cache_key)
      raise
    ensure
      Sidekiq::AttrPackage.delete(cache_key)
    end

    private

    def validate_user(user, cache_key)
      unless user.valid?
        log_failure("Invalid user attributes: #{user.errors.full_messages.join(', ')}", cache_key)
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

    def log_success(message, cache_key)
      Rails.logger.info("[GetSSOeTraitsByCspidJob] #{message}")
      StatsD.increment('worker.get_ssoe_traits_by_cspid.success', tags: ["cache_key:#{cache_key}"])
    end

    def log_failure(message, cache_key)
      Rails.logger.error("[GetSSOeTraitsByCspidJob] #{message}")
      StatsD.increment('worker.get_ssoe_traits_by_cspid.failure', tags: ["cache_key:#{cache_key}"])
    end
  end
end
