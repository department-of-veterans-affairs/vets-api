# frozen_string_literal: true

module MPI
  module Messages
    class RequestBuilder
      extend ActiveSupport::Concern

      attr_reader :extension, :body, :search_token

      def initialize(extension:, body:, search_token: nil)
        @extension = extension
        @body = body
        @search_token = search_token
      end

      def perform
        Ox.dump(build_document_component)
      end

      private

      def build_document_component
        document = Ox::Document.new(version: '1.0')
        document << build_instruct_component
        document << build_envelope_component
      end

      def build_instruct_component
        instruct = Ox::Instruct.new(:xml)
        instruct[:version] = '1.0'
        instruct[:encoding] = 'utf-8'
        instruct
      end

      def build_envelope_component
        envelope = build_envelope
        envelope << build_envelope_body_component
      end

      def build_envelope_body_component
        envelope_body = element('env:Body')
        envelope_body << build_message_component
      end

      def build_message_component
        message = build_header
        message << build_receiver
        message << build_sender
        message << build_attention_line if search_token
        message << body
      end

      def build_idm
        element(
          "idm:#{extension}",
          'xmlns:idm' => 'http://vaww.oed.oit.va.gov',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema‐instance',
          'xsi:schemaLocation' => "urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/#{extension}.xsd",
          'xmlns' => 'urn:hl7‐org:v3',
          'ITSVersion' => 'XML_1.0'
        )
      end

      def build_header
        element = build_idm
        element << element('id', root: '1.2.840.114350.1.13.0.1.7.1.1', extension: "200VGOV-#{SecureRandom.uuid}")
        element << element('creationTime', value: Time.now.utc.strftime('%Y%m%d%H%M%S'))
        element << element('versionCode', code: '4.1')
        element << element('interactionId', root: '2.16.840.1.113883.1.6', extension:)
        element << element('processingCode', code: processing_code)
        element << element('processingModeCode', code: 'T')
        element << element('acceptAckCode', code: 'AL')
      end

      def build_receiver
        receiver = element('receiver', typeCode: 'RCV')
        receiver << build_receiver_device
      end

      def build_receiver_device
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        device << element('id', root: '1.2.840.114350.1.13.999.234', extension: '200M')
      end

      def build_sender
        sender = element('sender', typeCode: 'SND')
        sender << build_sender_device
      end

      def build_attention_line
        attention_line = element('attentionLine')
        attention_line << element('keyWordText', {}, 'Search.Token')
        attention_line << element('value', { 'xsi:type' => 'ST' }, search_token)
      end

      def build_sender_device
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        device << element('id', root: MPI::Constants::VA_ROOT_OID, extension: '200VGOV')
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

      def processing_code
        Settings.mvi.processing_code
      end

      def element(name, attributes = {}, body_text = nil)
        element = Ox::Element.new(name)
        attributes.each { |key, value| element[key] = value }
        element.replace_text(body_text) if body_text
        element
      end
    end
  end
end
