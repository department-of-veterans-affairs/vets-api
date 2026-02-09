# frozen_string_literal: true

module SignIn
  class CredentialLevelCreator
    attr_reader :requested_acr,
                :type,
                :logingov_acr,
                :verified_at,
                :mhv_assurance,
                :level_of_assurance,
                :credential_ial,
                :credential_uuid

    def initialize(requested_acr:, type:, logingov_acr:, user_info:)
      @requested_acr = requested_acr
      @type = type
      @logingov_acr = logingov_acr
      @verified_at = user_info.verified_at
      @mhv_assurance = user_info.mhv_assurance
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
                          auto_uplevel: false)
    rescue ActiveModel::ValidationError => e
      Rails.logger.info("[SignIn][CredentialLevelCreator] error: #{e.message}", credential_type: type,
                                                                                requested_acr:,
                                                                                current_ial:,
                                                                                max_ial:,
                                                                                credential_uuid:)
      raise Errors::InvalidCredentialLevelError.new message: 'Unsupported credential authorization levels'
    end

    def max_ial
      case type
      when Constants::Auth::LOGINGOV
        logingov_max_ial
      when Constants::Auth::MHV
        mhv_max_ial
      else
        idme_max_ial
      end
    end

    def current_ial
      case type
      when Constants::Auth::LOGINGOV
        logingov_current_ial
      when Constants::Auth::MHV
        mhv_current_ial
      else
        idme_current_ial
      end
    end

    def logingov_max_ial
      verified_ial_level(verified_at || previously_verified?(:logingov_uuid))
    end

    def mhv_max_ial
      verified_ial_level(mhv_premium_verified?)
    end

    def idme_max_ial
      verified_ial_level(idme_loa3_or_previously_verified?)
    end

    def logingov_current_ial
      verified_ial_level(logingov_ial2?)
    end

    def mhv_current_ial
      verified_ial_level(requested_verified_account? && mhv_premium_verified?)
    end

    def idme_current_ial
      verified_ial_level(idme_classic_loa3_or_ial2?)
    end

    def mhv_premium_verified?
      Constants::Auth::MHV_PREMIUM_VERIFIED.include?(mhv_assurance)
    end

    def logingov_ial2?
      logingov_acr == Constants::Auth::LOGIN_GOV_IAL2
    end

    def idme_loa3_or_previously_verified?
      level_of_assurance == Constants::Auth::LOA_THREE || previously_verified?(:idme_uuid)
    end

    def idme_ial2?
      credential_ial == Constants::Auth::IAL_TWO
    end

    def idme_classic_loa3_or_ial2?
      [Constants::Auth::IDME_CLASSIC_LOA3, Constants::Auth::IAL_TWO].include?(credential_ial)
    end

    def verified_ial_level(verified)
      verified ? Constants::Auth::IAL_TWO : Constants::Auth::IAL_ONE
    end

    def requested_verified_account?
      [Constants::Auth::IAL2, Constants::Auth::LOA3, Constants::Auth::MIN].include?(requested_acr)
    end

    def unverified_account_with_forced_verification?
      requires_verified_account? && current_ial < Constants::Auth::IAL_TWO
    end

    def requires_verified_account?
      [Constants::Auth::IAL2, Constants::Auth::LOA3].include?(requested_acr)
    end

    def previously_verified?(identifier_type)
      user_verification = UserVerification.find_by(identifier_type => credential_uuid)
      user_verification&.verified?
    end
  end
end
