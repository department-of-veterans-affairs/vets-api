# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class SOAPParser < Faraday::Response::Middleware
          def on_complete(env)
            Raven.extra_context(
              url: env.url.to_s,
              body: env.body
            )

            case env.status
            when 200
              doc = parsed_doc(env.body)
              if doc_includes_error?(doc)
                raise Common::Client::Errors::HTTPError.new('SOAP service returned internal server error', 500)
              end
              env.body = doc
            else
              raise Common::Client::Errors::HTTPError.new('SOAP HTTP call failed', env.status)
            end
          end

          private

          def parsed_doc(body)
            @parsed_doc ||= Ox.parse(ensure_xml_prolog(body))
          end

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
