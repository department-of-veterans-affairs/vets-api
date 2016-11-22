# frozen_string_literal: true
require 'facilities/errors'

module Facilities
  module Middleware
    class GISJson < Faraday::Response::Middleware
      def on_complete(env)
        case env.status
        when 200
          doc = Oj.load env.body
          check_for_error_body doc
          env.body = doc
        else
          Rails.logger.error "GIS request failed: #{env.status} #{env.body}"
          raise Facilities::Errors::RequestError.new('GIS request failed', env.status)
        end
      rescue Oj::Error => error
        raise Facilities::Errors::SerializationError, error
      end

      private

      def check_for_error_body(doc)
        if doc['error']
          Rails.logger.error "GIS returned error: #{doc['error']['code']}, message: #{doc['error']['message']}"
          raise Facilities::Errors::RequestError.new(doc['error']['message'], doc['error']['code'])
        end
      end   
    end
  end
end
