module Identity
  class GetSSOeTraitsByCspidJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 5.minutes

    def perform(user_verification_id)
      user_verification = UserVerification.find(user_verification_id)
      user = user_verification.user

      response = SSOe::Service.new.get_traits(
        credential_method: user.identity.sign_in[:service_name],
        credential_id: user.identity.uuid,
        first_name: user.first_name,
        last_name: user.last_name,
        birth_date: user.birth_date&.strftime('%Y%m%d'),
        ssn: user.ssn,
        email: user.email,
        phone: user.phone,
        street1: user.address&.street,
        city: user.address&.city,
        state: user.address&.state,
        zipcode: user.address&.postal_code
      )

      if response[:icn].present?
        Rails.logger.info("[GetSSOeTraitsByCspidJob] Success for user #{user.uuid}, ICN: #{response[:icn]}")
        StatsD.increment('ssoe.traits_fetch.success')
      else
        Rails.logger.warn("[GetSSOeTraitsByCspidJob] Failure for user #{user.uuid}", response)
        StatsD.increment('ssoe.traits_fetch.failure')
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("[GetSSOeTraitsByCspidJob] UserVerification not found for ID #{user_verification_id}")
      StatsD.increment('ssoe.traits_fetch.user_verification_not_found')
    rescue => e
      Rails.logger.error("[GetSSOeTraitsByCspidJob] Unexpected error: #{e.message}")
      StatsD.increment('ssoe.traits_fetch.unexpected_error')
    end
  end
end
