# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class Request
      module Envelope
        module Aliases
          TARGET = 'tns'
          DATA = 'data'
        end

        # rubocop:disable Style/FormatStringToken
        TEMPLATE = <<~EOXML.freeze
          <?xml version="1.0" encoding="UTF-8"?>
          <env:Envelope
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
            %{namespaces}
          >
            <env:Header>
              <wsse:Security
                xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
              >
                <wsse:UsernameToken>
                  <wsse:Username>%{username}</wsse:Username>
                </wsse:UsernameToken>
                <vaws:VaServiceHeaders
                  xmlns:vaws="http://vbawebservices.vba.va.gov/vawss"
                >
                  <vaws:CLIENT_MACHINE>%{ip}</vaws:CLIENT_MACHINE>
                  <vaws:STN_ID>%{station_id}</vaws:STN_ID>
                  <vaws:applicationName>%{application_name}</vaws:applicationName>
                  <vaws:ExternalUid>%{external_uid}</vaws:ExternalUid>
                  <vaws:ExternalKey>%{external_key}</vaws:ExternalKey>
                </vaws:VaServiceHeaders>
              </wsse:Security>
            </env:Header>
            <env:Body>
              <#{Aliases::TARGET}:%{action}>%{body}</#{Aliases::TARGET}:%{action}>
            </env:Body>
          </env:Envelope>
        EOXML
        # rubocop:enable Style/FormatStringToken

        Headers =
          Data.define(
            :ip,
            :username,
            :station_id,
            :application_name,
            :external_id
          )

        class << self
          def build(namespaces:, headers:, action:, body:)
            namespaces =
              [].tap do |value|
                value << %(xmlns:#{Aliases::TARGET}="#{namespaces.target}")
                value << %(xmlns:#{Aliases::DATA}="#{namespaces.data}") if namespaces.data.present?
              end

            headers = headers.to_h
            external_id = headers.delete(:external_id).to_h

            format(
              TEMPLATE,
              namespaces: namespaces.join("\n"),
              **headers,
              **external_id,
              action:,
              body:
            )
          end
        end

        module Body
          class << self
            def build
              xml =
                Nokogiri::XML::Builder.new(
                  namespace_inheritance: false
                )

              # Need to declare an arbitrary root element with placeholder
              # namespace in order to leverage namespaced tag building. The root
              # element itself is later ignored and only used for its contents.
              #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
              xml.root("xmlns:#{Aliases::DATA}" => 'placeholder') do
                yield(xml, Aliases::DATA)
              end

              xml
                .doc.at('root')
                .children
                .to_xml
            end
          end
        end
      end
    end
  end
end
