# frozen_string_literal: true

require 'lighthouse/direct_deposit/parsers/error_parser'

module Lighthouse
  module DirectDeposit
    module Parsers
      class InvalidCredsParser < ErrorParser
        def parse_title
          @response.body['error']
        end

        def parse_detail
          @response.body['error_description']
        end
      end
    end
  end
end
