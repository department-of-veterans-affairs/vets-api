# frozen_string_literal: true
module Burials
  module Middleware
    module Response
      class SoapToJson < Faraday::Response::Middleware
        def on_complete(env)
          return unless env.url.to_s == Settings.burials.endpoint

          dump = Hash.from_xml Ox.dump(env.body)

          endpoint_resource = dump['Envelope']['Body'].keys[0]
          returns = dump['Envelope']['Body'][endpoint_resource]['return']

          env.response_headers['content-type'] = env.response_headers['content-type'].gsub('xml', 'json')
          env.body = { endpoint_resource&.gsub(/Response|get|receive/, '')&.downcase => returns }
        end
      end
    end
  end
end

Faraday::Response.register_middleware soap_to_json: Burials::Middleware::Response::SoapToJson
