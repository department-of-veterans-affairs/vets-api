# frozen_string_literal: true

require 'lighthouse/direct_deposit/error_response'

module Lighthouse
  module DirectDeposit
    class ErrorParser
      def self.parse(response)
        body = parse_body(response[:body])
        detail = parse_detail(body)
        status = parse_status(response[:status], detail)

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

      def self.parse_status(status, _detail)
        status
      end

      def self.parse_title(body)
        body[:error] || body[:title] || status_message_from(body[:status]) || 'Unknown error'
      end

      def self.parse_body(body)
        body.to_hash.with_indifferent_access
      end

      def self.parse_detail(body)
        messages = []
        messages.push(body[:error_codes][0][:error_code]) if body[:error_codes].present?
        messages.push(body[:error_codes][0][:detail]) if body[:error_codes].present?
        messages.push(body[:error_description] || body[:error] || body[:detail] || body[:message] || 'Unknown error')

        messages.compact.join(': ')
      end

      def self.parse_code(detail) # rubocop:disable Metrics/MethodLength
        return 'cnp.payment.api.rate.limit.exceeded' if detail.include? 'API rate limit exceeded'
        return 'cnp.payment.api.gateway.timeout' if detail.include? 'Did not receive a timely response'
        return 'cnp.payment.invalid.authentication.creds' if detail.include? 'Invalid authentication credentials'
        return 'cnp.payment.invalid.token' if detail.include? 'Invalid token'
        return 'cnp.payment.invalid.scopes' if detail.include? 'scopes are not configured'
        return 'cnp.payment.icn.not.found' if detail.include? 'No data found for ICN'
        return 'cnp.payment.icn.invalid' if detail.include? 'getDirectDeposit.icn size'
        return 'cnp.payment.account.number.invalid' if detail.include? 'payment.accountNumber.invalid'
        return 'cnp.payment.account.type.invalid' if detail.include? 'payment.accountType.invalid'
        return 'cnp.payment.account.number.fraud' if detail.include? 'Flashes on record'
        return 'cnp.payment.routing.number.invalid.checksum' if detail.include? 'accountRoutingNumber.invalidCheckSum'
        return 'cnp.payment.routing.number.invalid' if detail.include? 'payment.accountRoutingNumber.invalid'
        return 'cnp.payment.routing.number.fraud' if detail.include? 'Routing number related to potential fraud'
        return 'cnp.payment.restriction.indicators.present' if detail.include? 'restriction.indicators.present'
        return 'cnp.payment.day.phone.number.invalid' if detail.include? 'Day phone number is invalid'
        return 'cnp.payment.day.area.number.invalid' if detail.include? 'Day area number is invalid'
        return 'cnp.payment.night.phone.number.invalid' if detail.include? 'Night phone number is invalid'
        return 'cnp.payment.night.area.number.invalid' if detail.include? 'Night area number is invalid'
        return 'cnp.payment.mailing.address.invalid' if detail.include? 'field not entered for mailing address update'
        return 'cnp.payment.unspecified.error' if detail.include? 'GUIE50022'

        'cnp.payment.generic.error'
      end

      def self.data_source
        'Lighthouse Direct Deposit'
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
