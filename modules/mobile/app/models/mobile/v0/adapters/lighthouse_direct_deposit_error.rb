# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LighthouseDirectDepositError < ::Lighthouse::DirectDeposit::ErrorParser
        def self.parse(response)
          body = parse_body(response[:body])
          detail = parse_detail(body)
          status = parse_status(response[:status], detail)
          meta = parse_meta(detail, parse_code(detail))

          errors = [
            {
              title: parse_title(body),
              detail:,
              code: parse_code(detail),
              source: data_source,
              meta:
            }
          ]

          Lighthouse::DirectDeposit::ErrorResponse.new(status, errors)
        end

        def self.parse_status(status, detail)
          return '500' if detail.include?('accountRoutingNumber.invalidCheckSum') ||
                          detail.include?('payment.accountRoutingNumber.invalid') ||
                          detail.include?('Routing number related to potential fraud')

          status
        end

        def self.parse_meta(detail, code)
          {
            'messages' => [{
              'key' => code,
              severity: 'ERROR',
              text: parse_meta_message(detail)
            }]

          }
        end

        def self.parse_meta_message(detail)
          if detail.include?('accountRoutingNumber')
            'Financial institution routing number is invalid'
          else
            detail
          end
        end

        def self.parse_code(detail)
          if detail.include? 'accountRoutingNumber.invalidCheckSum'
            return 'payment.accountRoutingNumber.invalidCheckSum'
          end
          return 'payment.accountRoutingNumber.invalid' if detail.include? 'payment.accountRoutingNumber.invalid'
          return 'payment.accountRoutingNumber.fraud' if detail.include? 'Routing number related to potential fraud'

          super
        end
      end
    end
  end
end
