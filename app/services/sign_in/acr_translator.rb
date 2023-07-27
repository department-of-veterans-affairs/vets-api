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
      translate_acr
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

    def translate_idme_values
      case acr
      when 'loa1'
        Constants::Auth::IDME_LOA1
      when 'loa3'
        Constants::Auth::IDME_LOA3_FORCE
      when 'min'
        uplevel ? Constants::Auth::IDME_LOA3 : Constants::Auth::IDME_LOA1
      else
        raise Errors::InvalidAcrError.new message: 'Invalid ACR for idme'
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
        uplevel ? Constants::Auth::LOGIN_GOV_IAL2 : Constants::Auth::LOGIN_GOV_IAL1
      else
        raise Errors::InvalidAcrError.new message: 'Invalid ACR for logingov'
      end
    end
  end
end
