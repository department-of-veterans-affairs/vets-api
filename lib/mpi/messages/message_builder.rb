# frozen_string_literal: true

require 'ox'

module MPI
  module Messages
    module MessageBuilder
      extend ActiveSupport::Concern

      def to_xml(extension, body)
        message = build_idm(extension)
        message = add_header(message, extension)
        message << body
        env_body = element('env:Body')
        env_body << message
        envelope = build_envelope
        envelope << env_body
        doc = Ox::Document.new(version: '1.0')
        doc << envelope
        Ox.dump(doc)
      end

      def element(name, attrs = nil)
        el = Ox::Element.new(name)
        return el unless attrs

        attrs.each { |k, v| k == :text! ? el.replace_text(v) : el[k] = v }
        el
      end

      def build_idm(extension)
        element(
          "idm:#{extension}",
          'xmlns:idm' => 'http://vaww.oed.oit.va.gov',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema‐instance',
          'xsi:schemaLocation' => "urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/#{extension}.xsd",
          'xmlns' => 'urn:hl7‐org:v3',
          'ITSVersion' => 'XML_1.0'
        )
      end

      def add_header(message, extension)
        message << element('id', root: '1.2.840.114350.1.13.0.1.7.1.1', extension: "200VGOV-#{SecureRandom.uuid}")
        message << element('creationTime', value: Time.now.utc.strftime('%Y%m%d%H%M%S'))
        message << element('versionCode', code: '4.1')
        message << element('interactionId', root: '2.16.840.1.113883.1.6', extension: extension)
        message << element('processingCode', code: processing_code)
        message << element('processingModeCode', code: 'T')
        message << element('acceptAckCode', code: 'AL')
        message << build_receiver
        message << build_sender
      end

      def build_receiver
        receiver = element('receiver', typeCode: 'RCV')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        id = element('id', root: '1.2.840.114350.1.13.999.234', extension: '200M')
        device << id
        receiver << device
      end

      def build_sender
        sender = element('sender', typeCode: 'SND')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        id = element('id', root: '2.16.840.1.113883.4.349', extension: '200VGOV')
        device << id
        sender << device
      end

      def build_envelope
        env = element(
          'env:Envelope',
          'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
        )
        env << element('env:Header')
      end

      private

      def processing_code
        Settings.mvi.processing_code
      end
    end

    class MessageBuilderError < StandardError; end
  end
end
