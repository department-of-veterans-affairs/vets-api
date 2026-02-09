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
      when Constants::Auth::IAL2_REQUIRED
        ial2_enabled?(type:) ? Constants::Auth::IDME_IAL2 : invalid_acr!(type:)
      when 'min'
        uplevel ? Constants::Auth::IDME_LOA3 : Constants::Auth::IDME_LOA1
      else
        invalid_acr!(type:)
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
      ial2_enabled = ial2_enabled?(type:)

      case acr
      when 'ial1' then Constants::Auth::LOGIN_GOV_IAL1
      when 'ial2' then Constants::Auth::LOGIN_GOV_IAL2
      when Constants::Auth::IAL2_REQUIRED
        ial2_enabled ? Constants::Auth::LOGIN_GOV_IAL2_REQUIRED : invalid_acr!(type:)
      when Constants::Auth::IAL2_PREFERRED
        ial2_enabled ? Constants::Auth::LOGIN_GOV_IAL2_PREFERRED : invalid_acr!(type:)
      when 'min'
        uplevel ? Constants::Auth::LOGIN_GOV_IAL2 : Constants::Auth::LOGIN_GOV_IAL0
      else
        invalid_acr!(type:)
      end
    end

    def ial2_enabled?(type:)
      Flipper.enabled?("identity_#{type}_ial2_enforcement")
    end

    def invalid_acr!(type:)
      raise Errors::InvalidAcrError.new message: "Invalid ACR for #{type}"
    end
  end
end
