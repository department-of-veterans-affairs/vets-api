# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Request
        class ImmutableHeaders < Faraday::Middleware
          def call(env)
            headers = {}
            env.request_headers.each { |k, v| headers[ImmutableString.new(k)] = v }
            env.request_headers = headers
            @app.call(env)
          end
        end
      end
    end
  end
end

class ImmutableString < String
  def downcase
    self
  end

  def capitalize
    self
  end

  def to_s
    self
  end
end
