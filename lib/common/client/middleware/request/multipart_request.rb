require 'common/client/middleware/concerns/mime_types'

module Common
  module Client
    module Middleware
      module Request
        class MultipartRequest < Faraday::Middleware
          include MimeTypes

          def initialize(app)
            super(app)
          end

          def call(env)
            if env[:body].is_a?(Hash)
              env[:body].each do |key, value|
                env[:body][key] = io_object_for(value)
              end
            end
            @app.call(env)
          end

          private

          def io_object_for(value)
            if value.respond_to?(:to_io)
              Faraday::UploadIO.new(value, mime_type(value.path), value.path)
            elsif value.is_a?(Array)
              value.map { |value| io_object_for(value) }
            else
              value  
            end
          end
        end
      end
    end
  end
end

Faraday::Request.register_middleware multipart_request: Common::Client::Middleware::Request::MultipartRequest
