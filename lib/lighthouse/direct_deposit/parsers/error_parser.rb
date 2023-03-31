# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    module Parsers
      class ErrorParser
        attr_reader :status, :body

        def initialize(response)
          @response = response
          @status = response.status
          @body = response.body
        end

        def parse_body
          @body = {}

          @body['title']  = parse_title
          @body['detail'] = parse_detail
          @body['code']   = parse_code
          @body['status'] = parse_status
          @body['source'] = parse_source

          @body
        end

        def parse_title
          @response.body['title']
        end

        def parse_detail
          @response.body['detail']
        end

        def parse_code
          "LIGHTHOUSE_DIRECT_DEPOSIT#{@response.status}"
        end

        def parse_status
          @response.status
        end

        def parse_source
          'Lighthouse Direct Deposit'
        end

        def parse_first_error_code
          @response.body['errorCodes'][0]['errorCode']
        end

        def parse_first_error_detail
          @response.body['errorCodes'][0]['detail']
        end

        def bgs_error?
          @response.body['detail']&.include?('Raw response from BGS')
        end

        def error_codes?
          @response.body['errorCodes']&.present?
        end

        def status_message_from(code)
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
end
