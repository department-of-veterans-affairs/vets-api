# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class SOAPParser < Faraday::Response::Middleware
          include SentryLogging

          def on_complete(env)
            case env.status
            when 200
              doc = Ox.parse(ensure_xml_prolog(env.body))
              if doc_includes_error?(doc)
                raise Common::Client::Errors::HTTPError.new('SOAP service returned internal server error', 500)
              end
              env.body = doc
            else
              log_message_to_sentry(
                'SOAP HTTP call failed',
                :error,
                url: env.url.to_s,
                status: env.status,
                body: env.body
              )
              raise Common::Client::Errors::HTTPError.new('SOAP HTTP call failed', env.status)
            end
          end

          private

          def ensure_xml_prolog(xml)
            xml = xml.dup.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml =~ /^<\?xml/
            xml
          end

          def doc_includes_error?(doc)
            !doc.locate('env:Envelope/env:Body/env:Fault').empty?
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware soap_parser: Common::Client::Middleware::Response::SOAPParser
