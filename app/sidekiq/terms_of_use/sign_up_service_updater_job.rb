# frozen_string_literal: true

require 'map/sign_up/service'
require 'sidekiq/attr_package'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Job

    LOG_TITLE = '[TermsOfUse][SignUpServiceUpdaterJob]'

    sidekiq_options retry_for: 48.hours

    sidekiq_retries_exhausted do |job, exception|
      user_account = UserAccount.find_by(id: job['args'].first)
      version = job['args'].second
      agreement = user_account.terms_of_use_agreements.where(agreement_version: version).last if user_account.present?

      payload = {
        icn: user_account&.icn,
        version:,
        response: agreement&.response,
        response_time: agreement&.created_at&.iso8601,
        exception_message: exception.message
      }

      Rails.logger.warn("#{LOG_TITLE} retries exhausted", payload)
    end

    attr_reader :user_account_uuid, :version

    def perform(user_account_uuid, version)
      @user_account_uuid = user_account_uuid
      @version = version

      return if missing_sec_id? || agreement_unchanged?

      log_updated_icn
      terms_of_use_agreement.accepted? ? accept : decline
    end

    private

    def log_updated_icn
      if user_account.icn != mpi_profile.icn
        Rails.logger.info("#{LOG_TITLE} Detected changed ICN for user",
                          { icn: user_account.icn, mpi_icn: mpi_profile.icn })
      end
    end

    def map_client
      @map_client ||= MAP::SignUp::Service.new
    end

    def map_status
      @map_status ||= map_client.status(icn: mpi_profile.icn)
    end

    def agreement_unchanged?
      if terms_of_use_agreement.declined? != map_status[:opt_out] ||
         terms_of_use_agreement.accepted? != map_status[:agreement_signed]
        return false
      end

      Rails.logger.info("#{LOG_TITLE} Not updating Sign Up Service due to unchanged agreement",
                        { icn: user_account.icn })
      true
    end

    def accept
      map_client.agreements_accept(icn: mpi_profile.icn, signature_name:, version:)
    end

    def decline
      map_client.agreements_decline(icn: mpi_profile.icn)
    end

    def missing_sec_id?
      if mpi_profile.sec_id.present?
        validate_multiple_sec_ids
        return false
      end

      Rails.logger.info("#{LOG_TITLE} Sign Up Service not updated due to user missing sec_id",
                        { icn: user_account.icn })
      true
    end

    def validate_multiple_sec_ids
      if mpi_profile.sec_ids.many?
        Rails.logger.info("#{LOG_TITLE} Multiple sec_id values detected", { icn: user_account.icn })
      end
    end

    def user_account
      @user_account ||= UserAccount.find(user_account_uuid)
    end

    def terms_of_use_agreement
      user_account.terms_of_use_agreements.where(agreement_version: version).last
    end

    def signature_name
      "#{mpi_profile.given_names.first} #{mpi_profile.family_name}"
    end

    def mpi_profile
      @mpi_profile ||= MPI::Service.new.find_profile_by_identifier(identifier: user_account.icn,
                                                                   identifier_type: MPI::Constants::ICN)&.profile
    end
  end
end
