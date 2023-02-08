# frozen_string_literal: true

module Identity
  class UserAcceptableVerifiedCredentialCountsJob
    include Sidekiq::Worker

    LOG_MESSAGE = '[UserAcceptableVerifiedCredentialCountsJob] - Ran'
    PROVIDERS = %w[idme logingov dslogon mhv].freeze

    def perform
      build_total_verified_log_data
      build_provider_verified_log_data

      Rails.logger.info(LOG_MESSAGE, log_data)
    end

    private

    def build_total_verified_log_data
      # AVC added, AVC total
      log_data[:avc][:all][:added] =
        UserAcceptableVerifiedCredential.where(acceptable_verified_credential_at: range).count
      log_data[:avc][:all][:total] =
        UserAcceptableVerifiedCredential.where.not(acceptable_verified_credential_at: nil).count

      # IVC added, IVC total
      log_data[:ivc][:all][:added] = UserAcceptableVerifiedCredential.where(idme_verified_credential_at: range).count
      log_data[:ivc][:all][:total] = UserAcceptableVerifiedCredential.where.not(idme_verified_credential_at: nil).count

      # No AVC added, No AVC total
      log_data[:no_avc][:all][:added] =
        UserAcceptableVerifiedCredential.where(acceptable_verified_credential_at: nil).where(created_at: range).count
      log_data[:no_avc][:all][:total] =
        UserAcceptableVerifiedCredential.where(acceptable_verified_credential_at: nil).count

      # No IVC added, No IVC total
      log_data[:no_ivc][:all][:added] =
        UserAcceptableVerifiedCredential.where(idme_verified_credential_at: nil).where(created_at: range).count
      log_data[:no_ivc][:all][:total] = UserAcceptableVerifiedCredential.where(idme_verified_credential_at: nil).count
    end

    def build_provider_verified_log_data
      PROVIDERS.each do |provider|
        verifications = UserAcceptableVerifiedCredential.joins(user_account: :user_verifications)
                                                        .merge(UserVerification.public_send(provider))
        # AVC
        log_data[:avc][:"#{provider}"][:added] = verifications.where(acceptable_verified_credential_at: range).count
        log_data[:avc][:"#{provider}"][:total] = verifications.where.not(acceptable_verified_credential_at: nil).count

        # IVC
        log_data[:ivc][:"#{provider}"][:added] = verifications.where(idme_verified_credential_at: range).count
        log_data[:ivc][:"#{provider}"][:total] = verifications.where.not(idme_verified_credential_at: nil).count

        # No AVC
        log_data[:no_avc][:"#{provider}"][:added] = verifications.where(acceptable_verified_credential_at: nil)
                                                                 .where(created_at: range).count
        log_data[:no_avc][:"#{provider}"][:total] = verifications.where(acceptable_verified_credential_at: nil).count

        # No IVC
        log_data[:no_ivc][:"#{provider}"][:added] = verifications.where(idme_verified_credential_at: nil)
                                                                 .where(created_at: range).count
        log_data[:no_ivc][:"#{provider}"][:total] = verifications.where(idme_verified_credential_at: nil).count
      end
    end

    def log_data
      @log_data ||=
        {
          timestamp: Time.zone.yesterday.as_json,
          avc: new_providers_hash,
          ivc: new_providers_hash,
          no_avc: new_providers_hash,
          no_ivc: new_providers_hash
        }
    end

    def range
      @range ||= 1.day.ago.all_day
    end

    def new_providers_hash
      hash = { all: {} }
      PROVIDERS.each do |provider|
        hash[:"#{provider}"] = {}
      end
      hash
    end
  end
end
