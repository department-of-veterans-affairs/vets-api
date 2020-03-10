# frozen_string_literal: true
require 'pp'

module EVSS
  module DisabilityCompensationForm
    class Form526TimeoutMiddleware < Faraday::Response::Middleware
      class << self
        def response_json(response)
          return response.to_hash if response.respond_to? :to_hash
          if %i[status body headers].all? { |method| response.respond_to? method }
            return {
              status: response.status,
              body: response.body,
              headers: response.headers
            }
          end
          return response.as_json if response.respond_to? :as_json
          return response.to_h if response.respond_to? :to_h

          'failed to turn response into json'
        end

        def error_json(error)
          {
            error_class: error.class.to_s,
            message: error.message,
            backtrace: error.backtrace
          }.merge( error.respond_to?(:as_json) ? { as_json: error.as_json } : {} )
        end
      end

      def call(env)
        puts 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' # DEBUG
        puts "XX   #{Time.now}  #{env.to_s[20..80]}"                                            # DEBUG
        puts 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' # DEBUG
        super(env)
      rescue Timeout::Error, Faraday::TimeoutError => e
        puts "RESCUED!!" # DEBUG
        response_hash = if e.respond_to?(:response)
          { response: self.class.response_json(e.response) }
        else
          {}
        end
        PersonalInformationLog.create(
          error_class: 'EVSS::DisabilityCompensationForm Timeout',
          data: { error: self.class.error_json(e) }.merge(response_hash)
        )
        raise e
      end
    end
  end
end
