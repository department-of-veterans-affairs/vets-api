# frozen_string_literal: true
require 'rack/mime.rb'

module Common
  module Client
    module Middleware
      module Request
        class MultipartRequest < Faraday::Middleware
          include Rack::Mime

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
              Faraday::UploadIO.new(value, mime_type(File.extname(value.path)), value.path)
            elsif value.is_a?(Array)
              value.map { |each_value| io_object_for(each_value) }
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
