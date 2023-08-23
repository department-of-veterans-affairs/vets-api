# frozen_string_literal: true

module SignIn
  class CredentialLevelCreator
    attr_reader :requested_acr,
                :type,
                :logingov_acr,
                :verified_at,
                :mhv_assurance,
                :dslogon_assurance,
                :level_of_assurance,
                :credential_ial,
                :credential_uuid

    def initialize(requested_acr:, type:, logingov_acr:, user_info:)
      @requested_acr = requested_acr
      @type = type
      @logingov_acr = logingov_acr
      @verified_at = user_info.verified_at
      @mhv_assurance = user_info.mhv_assurance
      @dslogon_assurance = user_info.dslogon_assurance
      @level_of_assurance = user_info.level_of_assurance
      @credential_ial = user_info.credential_ial
      @credential_uuid = user_info.sub
    end

    def perform
      check_required_verification_level
      create_credential_level
    end

    private

    def check_required_verification_level
      if unverified_account_with_forced_verification?
        case type
        when Constants::Auth::MHV
          raise_unverified_credential_blocked_error(code: Constants::ErrorCode::MHV_UNVERIFIED_BLOCKED)
        else
          raise_unverified_credential_blocked_error(code: Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
        end
      end
    end

    def raise_unverified_credential_blocked_error(code:)
      raise Errors::UnverifiedCredentialBlockedError.new(
        message: 'Unverified credential for authorization requiring verified credential', code:
      )
    end

    def create_credential_level
      CredentialLevel.new(requested_acr:,
                          credential_type: type,
                          current_ial:,
                          max_ial:,
                          auto_uplevel:)
    rescue ActiveModel::ValidationError
      raise Errors::InvalidCredentialLevelError.new message: 'Unsupported credential authorization levels'
    end

    def max_ial
      case type
      when Constants::Auth::LOGINGOV
        verified_ial_level(verified_at)
      when Constants::Auth::MHV
        verified_ial_level(Constants::Auth::MHV_PREMIUM_VERIFIED.include?(mhv_assurance))
      when Constants::Auth::DSLOGON
        Rails.logger.info("[CredentialLevelCreator] DSLogon level of assurance: #{dslogon_assurance}, " \
                          "credential_uuid: #{credential_uuid}")
        verified_ial_level(Constants::Auth::DSLOGON_PREMIUM_VERIFIED.include?(dslogon_assurance))
      else
        verified_ial_level(level_of_assurance == Constants::Auth::LOA_THREE)
      end
    end

    def current_ial
      case type
      when Constants::Auth::LOGINGOV
        verified_ial_level(logingov_acr == Constants::Auth::LOGIN_GOV_IAL2 || previously_verified?(:logingov_uuid))
      when Constants::Auth::MHV
        verified_ial_level(requested_verified_account? && Constants::Auth::MHV_PREMIUM_VERIFIED.include?(mhv_assurance))
      when Constants::Auth::DSLOGON
        verified_ial_level(requested_verified_account? &&
                           Constants::Auth::DSLOGON_PREMIUM_VERIFIED.include?(dslogon_assurance))
      else
        verified_ial_level(credential_ial == Constants::Auth::IDME_CLASSIC_LOA3 || previously_verified?(:idme_uuid))
      end
    end

    def verified_ial_level(verified)
      verified ? Constants::Auth::IAL_TWO : Constants::Auth::IAL_ONE
    end

    def requested_verified_account?
      [Constants::Auth::IAL2, Constants::Auth::LOA3, Constants::Auth::MIN].include?(requested_acr)
    end

    def unverified_account_with_forced_verification?
      [Constants::Auth::IAL2, Constants::Auth::LOA3].include?(requested_acr) && current_ial < Constants::Auth::IAL_TWO
    end

    def previously_verified?(identifier_type)
      return false unless Settings.sign_in.auto_uplevel && requested_verified_account?

      user_verification = UserVerification.find_by(identifier_type => credential_uuid)
      user_verification&.verified?
    end

    def auto_uplevel
      case type
      when Constants::Auth::LOGINGOV
        logingov_acr != Constants::Auth::LOGIN_GOV_IAL2 && previously_verified?(:logingov_uuid)
      when Constants::Auth::IDME
        credential_ial != Constants::Auth::IDME_CLASSIC_LOA3 && previously_verified?(:idme_uuid)
      else
        false
      end
    end
  end
end
