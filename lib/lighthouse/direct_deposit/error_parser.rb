# frozen_string_literal: true

require 'lighthouse/direct_deposit/error_response'

module Lighthouse
  module DirectDeposit
    class ErrorParser
      def self.parse(response)
        status = response[:status]
        body = response[:body].with_indifferent_access
        detail = parse_detail(body)

        errors = [
          {
            title: parse_title(body),
            detail:,
            code: parse_code(detail),
            source: data_source
          }
        ]

        Lighthouse::DirectDeposit::ErrorResponse.new(status, errors)
      end

      def self.parse_title(body)
        body[:error] || body[:title] || status_message_from(body[:status]) || 'Unknown error'
      end

      def self.parse_detail(body)
        return parse_first_error_code(body) if error_codes?(body)

        body[:error_description] || body[:error] || body[:detail] || body[:message] || 'Unknown error'
      end

      def self.parse_code(detail)
        return 'cnp.payment.api.rate.limit.exceeded' if detail.include? 'API rate limit exceeded'
        return 'cnp.payment.invalid.authentication.creds' if detail.include? 'Invalid authentication credentials'
        return 'cnp.payment.invalid.token' if detail.include? 'Invalid token'
        return 'cnp.payment.invalid.scopes' if detail.include? 'scopes are not configured'
        return 'cnp.payment.icn.not.found' if detail.include? 'No data found for ICN'
        return 'cnp.payment.icn.invalid' if detail.include? 'getDirectDeposit.icn size'
        return 'cnp.payment.account.number.invalid' if detail.include? 'payment.accountNumber.invalid'
        return 'cnp.payment.routing.number.invalid' if detail.include? 'payment.accountRoutingNumber.invalid'
        return 'cnp.payment.account.type.invalid' if detail.include? 'payment.accountType.invalid'
        return 'cnp.payment.routing.number.invalid.checksum' if detail.include? 'accountRoutingNumber.invalidCheckSum'
        return 'cnp.payment.restriction.indicators.present'  if detail.include? 'restriction.indicators.present'
        return 'cnp.payment.routing.number.fraud' if detail.include? 'Routing number related to potential fraud'
        return 'cnp.payment.accounting.number.fraud' if detail.include? 'Flashes on record'
        return 'cnp.payment.unspecified.error' if detail.include? 'GUIE50022'

        'cnp.payment.generic.error'
      end

      def self.data_source
        'Lighthouse Direct Deposit'
      end

      def self.parse_first_error_code(body)
        body[:error_codes][0][:error_code]
      end

      def self.parse_first_error_detail(body)
        body[:error_codes][0][:detail]
      end

      def self.error_codes?(body)
        body[:error_codes].present?
      end

      def self.status_message_from(code)
        case code
        when 401
          'Not Authorized'
        when 403
          'Forbidden'
        when 413
          'Payload too large'
        when 429
          'Too many requests'
        end
      end
    end
  end
end
