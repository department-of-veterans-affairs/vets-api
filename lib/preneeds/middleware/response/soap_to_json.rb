# frozen_string_literal: true
module Preneeds
  module Middleware
    module Response
      class SoapToJson < Faraday::Response::Middleware
        def on_complete(env)
          return unless env.url.to_s == Settings.preneeds.endpoint

          dump = Hash.from_xml Ox.dump(env.body)
          endpoint_resource = dump['Envelope']['Body'].keys[0]

          unless %w(receivePreneedsApplication addAttachment).include?(endpoint_resource)
            returns = dump['Envelope']['Body'][endpoint_resource]['return']

            env.response_headers['content-type'] = env.response_headers['content-type'].gsub('xml', 'json')
            env.body = { endpoint_resource&.gsub(/Response|get/, '')&.underscore&.downcase => returns }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware soap_to_json: Preneeds::Middleware::Response::SoapToJson
