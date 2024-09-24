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

      return if !sec_id? || agreement_unchanged?

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

    def client
      @client ||= MAP::SignUp::Service.new
    end

    def status
      @status ||= client.status(icn: mpi_profile.icn)
    end

    def declined?
      status[:opt_out] == true
    end

    def accepted?
      status[:agreement_signed] == true
    end

    def agreement_unchanged?
      return false unless terms_of_use_agreement

      unchanged = (terms_of_use_agreement.declined? && declined?) && (terms_of_use_agreement.accepted? && accepted?)

      if unchanged == true
        Rails.logger.info("#{LOG_TITLE} Agreement not changed",
                          { icn: user_account.icn })
      end
      unchanged
    end

    def accept
      client.agreements_accept(icn: mpi_profile.icn, signature_name:, version:)
    end

    def decline
      client.agreements_decline(icn: mpi_profile.icn)
    end

    def sec_id?
      if mpi_profile.sec_id.present?
        validate_multiple_sec_ids
        return true
      end

      Rails.logger.info("#{LOG_TITLE} Sign Up Service not updated due to user missing sec_id",
                        { icn: user_account.icn })
      false
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
