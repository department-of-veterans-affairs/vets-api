# frozen_string_literal: true

require 'map/sign_up/service'
require 'sidekiq/attr_package'

module TermsOfUse
  class SignUpServiceUpdaterJob
    include Sidekiq::Job

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

      Rails.logger.warn('[TermsOfUse][SignUpServiceUpdaterJob] retries exhausted', payload)
    end

    attr_reader :user_account_uuid, :version

    def perform(user_account_uuid, version)
      @user_account_uuid = user_account_uuid
      @version = version

      return unless sec_id?

      terms_of_use_agreement.accepted? ? accept : decline
    end

    private

    def accept
      MAP::SignUp::Service.new.agreements_accept(icn:, signature_name:, version:)
    end

    def decline
      MAP::SignUp::Service.new.agreements_decline(icn:)
    end

    def sec_id?
      return true if mpi_profile.sec_id.present?

      Rails.logger.info('[TermsOfUse][SignUpServiceUpdaterJob] Sign Up Service not updated due to user missing sec_id',
                        { icn: })
      false
    end

    def user_account
      @user_account ||= UserAccount.find(user_account_uuid)
    end

    def icn
      @icn ||= user_account.icn
    end

    def terms_of_use_agreement
      user_account.terms_of_use_agreements.where(agreement_version: version).last
    end

    def signature_name
      "#{mpi_profile.given_names.first} #{mpi_profile.family_name}"
    end

    def mpi_profile
      @mpi_profile ||= MPI::Service.new.find_profile_by_identifier(identifier: icn,
                                                                   identifier_type: MPI::Constants::ICN)&.profile
    end
  end
end
