require 'ox'

module MVI
  module Messages
    module MessageBuilder
      attr_reader :doc

      INTERACTION_ID = '^PN^200VETS^USDVA'.freeze

      def initialize
        @doc = Ox::Document.new(:version => '1.0')
      end

      def header(extension)
        @message << element('id', root: '1.2.840.114350.1.13.0.1.7.1.1', extension: "200VGOV-#{SecureRandom.uuid}")
        @message << element('creationTime', value: Time.now.utc.strftime('%Y%m%d%M%H%M%S'))
        @message << element('versionCode', code: '3.0')
        @message << element('interactionId', root: '2.16.840.1.113883.1.6', extension: extension)
        @message << element('processingCode', code: Rails.env.production? ? 'P' : 'D')
        @message << element('processingModeCode', code: 'T')
        @message << element('acceptAckCode', code: 'AL')
        receiver = element('receiver', typeCode: 'RCV')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        id = element('id', root: '1.2.840.114350.1.13.999.234', extension: '200M')
        device << id
        receiver << device
        @message << receiver
        sender = element('sender', typeCode: 'SND')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        id = element('id', root: '2.16.840.1.113883.4.349', extension: '200VGOV')
        device << id
        sender << device
        @message << sender
      end

      private

      def element(name, attrs = nil)
        el = Ox::Element.new(name)
        return el unless attrs
        attrs.each { |k, v| k == :text! ? el.replace_text(v) : el[k] = v }
        el
      end

      def envelope_body(message)
        env = element('env:Envelope',
          'xmlns:soapenc' => "http://schemas.xmlsoap.org/soap/encoding/",
          'xmlns:xsd' => "http://www.w3.org/2001/XMLSchema",
          'xmlns:env' => "http://schemas.xmlsoap.org/soap/envelope/",
          'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance"
        )
        env << element('env:Header')
        body = element('env:Body')
        body << message
        env << body
        env
      end

      def idm(extension)
        element("idm:#{extension}",
          :'xmlns:idm' => 'http://vaww.oed.oit.va.gov',
          :'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema‐instance",
          :'xsi:schemaLocation' => "urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/#{extension}.xsd",
          xmlns: 'urn:hl7‐org:v3',
          ITSVersion: 'XML_1.0'
        )
      end
    end
  end
end
