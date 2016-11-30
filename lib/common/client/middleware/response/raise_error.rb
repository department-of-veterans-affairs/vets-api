# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class RaiseError < Faraday::Response::Middleware
          attr_reader :service_acronym, :error_klass, :detail_key, :code_key, :source_key, :meta_key

          def initialize(app, service_acronym, options = {})
            @service_acronym = service_acronym
            @error_klass = Common::Exceptions::BackendServiceException
            @detail_key  = options[:detail_key]  || 'detail'
            @code_key    = options[:code_key]    || 'code'
            @source_key  = options[:source_key]  || 'source'
            @meta_key    = options[:meta_key]    || 'meta'

            super(app)
          end

          def on_complete(env)
            return if env.success?
            binding.pry
            raise error_klass.new(error_type(env), response_values(env))
          end

          private

          def code(env)
            env[:body][code_key]
          end

          def error_type(env)
            if code(env).present?
              "#{service_acronym.upcase}#{code(env)}"
            else
              nil
            end
          end

          def response_values(env)
            {
              status: env.status.to_i,
              detail: env[:body][detail_key],
              code:   code(env),
              source: env[:body][source_key],
              meta:   env[:body][meta_key]
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_error: Common::Client::Middleware::Response::RaiseError
