require 'common/client/middleware/concerns/mime_types'

module Common
  module Client
    module Middleware
      module Request
        class MultipartRequest < Faraday::Middleware
          include MimeTypes

          def call(env)
            if env[:body].is_a?(Hash)
              binding.pry
              env[:body].each do |key, value|
                if value.respond_to?(:to_io)
                  env[:body][key] = Faraday::UploadIO.new(value, mime_type(value.path), value.path)
                elsif value.is_a?(Array)
                  binding.pry
                end
              end
            end
            @app.call(env)
          end
        end
      end
    end
  end
end

Faraday::Request.register_middleware multipart_request: Common::Client::Middleware::Request::MultipartRequest
