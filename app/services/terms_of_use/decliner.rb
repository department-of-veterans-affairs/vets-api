# frozen_string_literal: true

require 'terms_of_use/exceptions'
require 'sidekiq/attr_package'

module TermsOfUse
  class Decliner
    include ActiveModel::Validations

    attr_reader :user_account, :icn, :version

    validates :user_account, :icn, :version, presence: true

    def initialize(user_account:, version:)
      @user_account = user_account
      @icn = user_account&.icn
      @version = version

      validate!
    rescue ActiveModel::ValidationError => e
      log_and_raise_decliner_error(e)
    end

    def perform!
      terms_of_use_agreement.declined!
      if mpi_profile.sec_id
        update_sign_up_service
      else
        Rails.logger.info('[TermsOfUse] [Decliner] Sign Up Service not updated due to user missing sec_id', { icn: })
      end
      Logger.new(terms_of_use_agreement:).perform

      terms_of_use_agreement
    rescue ActiveRecord::RecordInvalid => e
      log_and_raise_decliner_error(e)
    end

    private

    def terms_of_use_agreement
      @terms_of_use_agreement ||= user_account.terms_of_use_agreements.new(agreement_version: version)
    end

    def update_sign_up_service
      Rails.logger.info('[TermsOfUse] [Decliner] attr_package key', { icn:, attr_package_key: })
      SignUpServiceUpdaterJob.perform_async(attr_package_key)
    end

    def log_and_raise_decliner_error(error)
      Rails.logger.error("[TermsOfUse] [Decliner] Error: #{error.message}", { user_account_id: user_account&.id })
      raise Errors::DeclinerError, error.message
    end

    def signature_name
      "#{mpi_profile.given_names.first} #{mpi_profile.family_name}"
    end

    def mpi_profile
      @mpi_profile ||= MPI::Service.new.find_profile_by_identifier(identifier: icn,
                                                                   identifier_type: MPI::Constants::ICN)&.profile
    end

    def attr_package_key
      @attr_package_key ||= Sidekiq::AttrPackage.create(icn:, signature_name:, version:, expires_in: 2.days)
    end
  end
end
