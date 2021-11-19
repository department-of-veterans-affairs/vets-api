# frozen_string_literal: true

require 'rack/mime'

module Common
  module Client
    module Middleware
      module Request
        class MultipartRequest < Faraday::Middleware
          include Rack::Mime

          def call(env)
            return @app.call(env) unless env[:body].is_a?(Hash)

            io_keys = []

            env[:body].each do |key, value|
              env[:body][key] = io_object_for(key, value, io_keys)
            end

            if io_keys.any?
              env[:body].except(*io_keys.uniq).each do |key, value|
                env[:body][key] = make_io_for_body(key, value)
              end
            end

            @app.call(env)
          end

          private

          def io_object_for(key, value, io_keys)
            if value.respond_to?(:to_io)
              io_keys << key
              Faraday::UploadIO.new(
                value,
                mime_type(File.extname(value.path)),
                file_name(value)
              )
            elsif value.is_a?(Array)
              value.map { |each_value| io_object_for(key, each_value, io_keys) }
            else
              value
            end
          end

          def make_io_for_body(key, value)
            Faraday::UploadIO.new(
              StringIO.new(value.to_json),
              'application/json',
              key.to_s
            )
          end

          def file_name(value)
            value.original_filename || value.path
          end
        end
      end
    end
  end
end

Faraday::Request.register_middleware multipart_request: Common::Client::Middleware::Request::MultipartRequest
