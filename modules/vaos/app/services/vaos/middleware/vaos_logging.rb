# frozen_string_literal: true

module VAOS
  module Middleware
    class VaosLogging < Faraday::Middleware
      def initialize(app, service_name)
        super(app)
        @service_name = service_name
      end

      def call(env)
        start_time = Time.current

        @app.call(env).on_complete do |response_env|
          jti = jti(env, response_env)
          duration = Time.current - start_time
          status = response_env.status

          if status.between?(200..299) 
            logger.info('vaos service call succeeded:',
              duration: duration,
              status: status,
              jti: jti,
              service_name: @service_name,
              url: env.url.to_s
            )
          else
            logger.warn('vaos service call failed:',
              duration: duration,
              status: status,
              jti: jti,
              service_name: @service_name,
              url: env.url.to_s
            )
          end
        end
      end

      private

      def decode_jwt(token)
       JWT.decode(token, rsa_private.public_key, true, algorithm: 'RS512').first
      end

      def user_session_request?(env)
        env.url.to_s.include?('users/v2/session?processRules=true') ? true : false
      end

      def rsa_private
        OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
      end
  
      def jti(env, response_env)
        if user_session_request?(env)
          decode_jwt(response_env.body)['jti']
        else
          decode_jwt(env.headers['X-Vamf-Jwt'])
        end
      end
    end
  end
end


Faraday::Middleware.register_middleware vaos_logging: VAOS::Middleware::VaosLogging
