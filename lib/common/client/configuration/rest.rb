require_relative 'base'

module Common
  module Client
    module Configuration
      class REST < Base
        self.request_types = %i[get put post delete].freeze
        self.base_request_headers = {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => user_agent
        }.freeze
      end
    end
  end
end
