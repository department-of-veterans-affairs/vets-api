# frozen_string_literal: true

module AppealsApi
  module IcnParameterValidation
    extend ActiveSupport::Concern
    include AppealsApi::OpenidAuth # This concern depends on `token_validation_result`

    ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/

    def validate_icn_parameter!
      if params[:icn] && !ICN_REGEX.match?(params[:icn])
        raise(
          Common::Exceptions::UnprocessableEntity,
          detail: "'icn' parameter has an invalid format. Pattern: #{ICN_REGEX.inspect}"
        )
      end

      if veteran_icn_from_token.present? && params[:icn].present? && veteran_icn_from_token != params[:icn]
        # If both a veteran-scoped auth token and an ICN parameter are received, the ICNs must match
        raise(Common::Exceptions::Forbidden,
              detail: "Invalid 'icn' parameter: Veterans may access only their own records")
      elsif veteran_icn_from_token.blank? && params[:icn].blank?
        # If the auth token is a system or representative token, an ICN parameter is required
        raise(Common::Exceptions::ParameterMissing, 'icn')
      end

      if veteran_icn_from_token.present? && !ICN_REGEX.match?(veteran_icn_from_token)
        # rubocop:disable Layout/LineLength
        Rails.logger.error("The Veteran ICN '#{veteran_icn_from_token}', which was returned by the token validation server, has an invalid format. This should never happen.")
        # rubocop:enable Layout/LineLength
      end
    end

    def veteran_icn
      veteran_icn_from_token.presence || params[:icn]
    end

    private

    def veteran_icn_from_token
      token_validation_result&.veteran_icn # Will only be present on tokens with veteran/* scopes
    end
  end
end
