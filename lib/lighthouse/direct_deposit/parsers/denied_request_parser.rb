# frozen_string_literal: true

require 'lighthouse/direct_deposit/parsers/error_parser'

module Lighthouse
  module DirectDeposit
    module Parsers
      class DeniedRequestParser < ErrorParser
        def parse_title
          status_message_from(@response.status)
        end

        def parse_detail
          @response.body['message']
        end
      end
    end
  end
end
