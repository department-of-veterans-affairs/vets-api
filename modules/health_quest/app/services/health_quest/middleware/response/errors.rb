# frozen_string_literal: true

module HealthQuest
  module Middleware
    module Response
      class Errors < Faraday::Middleware
        def on_complete(env)
          return if env.success?

          Sentry.set_extras(message: env.body, url: env.url)
          case env.status
          when 400, 409
            error_400(env.body)
          when 403
            raise Common::Exceptions::BackendServiceException.new('HEALTH_QUEST_403', source: self.class)
          when 404
            raise Common::Exceptions::BackendServiceException.new('HEALTH_QUEST_404', source: self.class)
          when 500..510
            raise Common::Exceptions::BackendServiceException.new('HEALTH_QUEST_502', source: self.class)
          else
            raise Common::Exceptions::BackendServiceException.new('VA900', source: self.class)
          end
        end

        def error_400(body)
          raise Common::Exceptions::BackendServiceException.new(
            'HEALTH_QUEST_400',
            title: 'Bad Request',
            detail: parse_error(body),
            source: self.class
          )
        end

        def parse_error(body)
          parsed = JSON.parse(body)
          if parsed['errors']
            parsed['errors'].first['errorMessage']
          else
            parsed['message']
          end
        rescue
          body
        end
      end
    end
  end
end

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
