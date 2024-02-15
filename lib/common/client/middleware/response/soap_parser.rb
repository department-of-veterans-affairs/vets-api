# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class SOAPParser < Faraday::Middleware
          def on_complete(env)
            case env.status
            when 200
              doc = parse_doc(env.body)
              if doc_includes_error?(doc)
                log_error_details(env)
                raise Common::Client::Errors::HTTPError.new('SOAP service returned internal server error', 500)
              end
              env.body = doc
            else
              log_error_details(env)
              raise Common::Client::Errors::HTTPError.new('SOAP HTTP call failed', env.status)
            end
          end

          private

          def log_error_details(env)
            Sentry.set_extras(url: env.url.to_s, body: env.body)
          end

          def parse_doc(body)
            Ox.parse(ensure_xml_prolog(body))
          end

          def ensure_xml_prolog(xml)
            xml = xml.dup.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml.match?(/^<\?xml/)
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
