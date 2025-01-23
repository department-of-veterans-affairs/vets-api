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
        prefix = 'direct.deposit'

        return "#{prefix}.api.rate.limit.exceeded" if detail.include? 'API rate limit exceeded'
        return "#{prefix}.api.gateway.timeout" if detail.include? 'Did not receive a timely response'
        return "#{prefix}.invalid.authentication.creds" if detail.include? 'Invalid authentication credentials'
        return "#{prefix}.invalid.token" if detail.include? 'Invalid token'
        return "#{prefix}.invalid.scopes" if detail.include? 'scopes are not configured'
        return "#{prefix}.icn.not.found" if detail.include? 'No data found for ICN'
        return "#{prefix}.icn.invalid" if detail.include? 'getDirectDeposit.icn size'
        return "#{prefix}.account.number.invalid" if detail.include? 'payment.accountNumber.invalid'
        return "#{prefix}.account.type.invalid" if detail.include? 'payment.accountType.invalid'
        return "#{prefix}.account.number.fraud" if detail.include? 'Flashes on record'
        return "#{prefix}.routing.number.invalid.checksum" if detail.include? 'accountRoutingNumber.invalidCheckSum'
        return "#{prefix}.routing.number.invalid" if detail.include? 'payment.accountRoutingNumber.invalid'
        return "#{prefix}.routing.number.fraud" if detail.include? 'Routing number related to potential fraud'
        return "#{prefix}.restriction.indicators.present" if detail.include? 'restriction.indicators.present'
        return "#{prefix}.day.phone.number.invalid" if detail.include? 'Day phone number is invalid'
        return "#{prefix}.day.area.number.invalid" if detail.include? 'Day area number is invalid'
        return "#{prefix}.night.phone.number.invalid" if detail.include? 'Night phone number is invalid'
        return "#{prefix}.night.area.number.invalid" if detail.include? 'Night area number is invalid'
        return "#{prefix}.mailing.address.invalid" if detail.include? 'field not entered for mailing address update'
        return "#{prefix}.potential.fraud" if %w[GUIE50022 GUIE50041].any? { |code| detail.include?(code) }

        "#{prefix}.generic.error"
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
