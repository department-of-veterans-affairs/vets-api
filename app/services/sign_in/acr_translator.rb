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
      when 'idme'
        translate_idme_values
      when 'logingov'
        translate_logingov_values
      when 'dslogon'
        translate_dslogon_values
      when 'mhv'
        translate_mhv_values
      else
        raise Errors::InvalidTypeError, message: 'Invalid Type value'
      end
    end

    def translate_idme_values
      case acr
      when 'loa1'
        LOA::IDME_LOA1_VETS
      when 'loa3'
        LOA::IDME_LOA3
      when 'min'
        uplevel ? LOA::IDME_LOA3 : LOA::IDME_LOA1_VETS
      else
        raise Errors::InvalidAcrError, message: 'Invalid ACR for idme'
      end
    end

    def translate_dslogon_values
      case acr
      when 'loa1'
        LOA::IDME_DSLOGON_LOA1
      when 'loa3'
        LOA::IDME_DSLOGON_LOA3
      when 'min'
        uplevel ? LOA::IDME_DSLOGON_LOA3 : LOA::IDME_DSLOGON_LOA1
      else
        raise Errors::InvalidAcrError, message: 'Invalid ACR for dslogon'
      end
    end

    def translate_mhv_values
      case acr
      when 'loa1', 'loa3', 'min'
        LOA::IDME_MHV_LOA1
      else
        raise Errors::InvalidAcrError, message: 'Invalid ACR for mhv'
      end
    end

    def translate_logingov_values
      case acr
      when 'ial1'
        IAL::LOGIN_GOV_IAL1
      when 'ial2'
        IAL::LOGIN_GOV_IAL2
      when 'min'
        uplevel ? IAL::LOGIN_GOV_IAL2 : IAL::LOGIN_GOV_IAL1
      else
        raise Errors::InvalidAcrError, message: 'Invalid ACR for logingov'
      end
    end
  end
end
