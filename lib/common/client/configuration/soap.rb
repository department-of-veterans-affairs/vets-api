# frozen_string_literal: true
require_relative 'base'

module Common
  module Client
    module Configuration
      class SOAP < Base
        self.request_types = %i(post).freeze
        self.base_request_headers = {
          'Accept' => 'text/xml;charset=UTF-8',
          'Content-Type' => 'text/xml;charset=UTF-8',
          'User-Agent' => user_agent
        }.freeze
      end
    end
  end
end
