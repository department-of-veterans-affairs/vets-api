# frozen_string_literal: true

require 'lighthouse/direct_deposit/parsers/error_parser'

module Lighthouse
  module DirectDeposit
    module Parsers
      class BadRequestParser < ErrorParser
        def parse_title
          @response.body['title']
        end

        def parse_detail
          if bgs_error?
            sentences = @response.body['detail'].split('.').reverse
            sentences.first.strip
          else
            message = @response.body['detail']
            error_codes? ? "#{message} #{parse_first_error_detail}" : message
          end
        end

        def parse_code
          return code_from(parse_detail) if bgs_error?
          return parse_first_error_code if error_codes?

          "LIGHTHOUSE_DIRECT_DEPOSIT#{@response.status}"
        end

        private

        def code_from(message)
          if message.include?('potential fraud')
            'cnp.payment.routing.number.fraud.message'
          else
            'cnp.payment.flashes.on.record.message'
          end
        end
      end
    end
  end
end
