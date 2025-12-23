# frozen_string_literal: true

module SignIn
  class AcrTranslator
    attr_reader :acr, :type, :uplevel

    def initialize(acr:, type:, uplevel: false)
      @acr = acr
      @type = type
      @uplevel = uplevel
    end

    def perform
      { acr: translate_acr, acr_comparison: translate_acr_comparison }.compact
    end

    private

    def translate_acr
      case type
      when Constants::Auth::IDME
        translate_idme_values
      when Constants::Auth::LOGINGOV
        translate_logingov_values
      when Constants::Auth::DSLOGON
        translate_dslogon_values
      when Constants::Auth::MHV
        translate_mhv_values
      else
        raise Errors::InvalidTypeError.new message: 'Invalid Type value'
      end
    end

    def translate_acr_comparison
      type == Constants::Auth::IDME && acr == 'min' && !uplevel ? Constants::Auth::IDME_COMPARISON_MINIMUM : nil
    end

    def translate_idme_values
      case acr
      when 'loa1'
        Constants::Auth::IDME_LOA1
      when 'loa3'
        Constants::Auth::IDME_LOA3_FORCE
      when 'ial2'
        ial2_enabled? ? Constants::Auth::IDME_IAL2 : invalid_acr!
      when 'min'
        uplevel ? Constants::Auth::IDME_LOA3 : Constants::Auth::IDME_LOA1
      else
        invalid_acr!
      end
    end

    def translate_dslogon_values
      case acr
      when 'loa1', 'loa3', 'min'
        Constants::Auth::IDME_DSLOGON_LOA1
      else
        raise Errors::InvalidAcrError.new message: 'Invalid ACR for dslogon'
      end
    end

    def translate_mhv_values
      case acr
      when 'loa1', 'loa3', 'min'
        Constants::Auth::IDME_MHV_LOA1
      else
        raise Errors::InvalidAcrError.new message: 'Invalid ACR for mhv'
      end
    end

    def translate_logingov_values
      case acr
      when 'ial1'
        Constants::Auth::LOGIN_GOV_IAL1
      when 'ial2'
        Constants::Auth::LOGIN_GOV_IAL2
      when 'min'
        uplevel ? Constants::Auth::LOGIN_GOV_IAL2 : Constants::Auth::LOGIN_GOV_IAL0
      else
        raise Errors::InvalidAcrError.new message: 'Invalid ACR for logingov'
      end
    end

    def ial2_enabled?
      Flipper.enabled?(:identity_ial2_enforcement) && Settings.vsp_environment != 'production'
    end

    def invalid_acr!
      raise Errors::InvalidAcrError.new message: 'Invalid ACR for idme'
    end
  end
end
