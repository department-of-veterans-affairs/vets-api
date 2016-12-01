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
            raise error_klass.new(i18n_error_key(env), response_values(env))
          end

          private

          def code(env)
            "#{service_acronym.upcase}#{env[:body][code_key]}"
          end

          def i18n_error_key(env)
            if I18n.exists?("common.exceptions.#{code(env)}")
              "common.exceptions.#{code(env)}"
            else
              Rails.logger.warn "The following exception should be added to locales: \n #{response_values(env)}"
              'common.exceptions.backend_service_exception'
            end
          end

          # This method is not to be used for passing options. It is used to notify that
          # a new error was presented from a backend service that is not currently mapped
          # in locales
          def response_values(env)
            {
              status: env.status.to_i,
              detail: env[:body][detail_key],
              code:   code(env),
              source: env[:body][source_key]
            }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_error: Common::Client::Middleware::Response::RaiseError
