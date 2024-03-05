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

      # If an ICN parameter is received and we have an ICN from the token, the ICNs must match:
      validate_token_icn_access!(params[:icn], forbidden_error_key: 'appeals_api.errors.forbidden_parameter_icn')

      # If the auth token had no veteran ICN, an ICN parameter is required:
      if token_validation_result&.veteran_icn.blank? && params[:icn].blank?
        raise(Common::Exceptions::ParameterMissing.new(
                'icn',
                { detail: I18n.t('appeals_api.errors.missing_icn_parameter') }
              ))
      end
    end

    # Raises if the request includes a veteran token whose ICN doesn't match the `target_icn` (if provided)
    def validate_token_icn_access!(target_icn = nil, forbidden_error_key: 'appeals_api.errors.forbidden_token_icn')
      if (token_icn = token_validation_result&.veteran_icn.presence)
        unless ICN_REGEX.match?(token_icn)
          Rails.logger.error(
            "The Veteran ICN '#{token_icn}', which was returned by the token validation server, has an invalid" \
            ' format. This should never happen.'
          )
        end

        if target_icn.present? && token_icn != target_icn
          raise(Common::Exceptions::Forbidden, detail: I18n.t(forbidden_error_key))
        end
      end
    end

    def veteran_icn
      token_validation_result&.veteran_icn.presence || params[:icn]
    end
  end
end
