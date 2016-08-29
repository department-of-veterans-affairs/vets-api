require 'ox'

module MVI
  module Messages
    module MessageBuilder
      attr_reader :doc

      SITE_KEY = 'ABC123'.freeze
      ROOT_ID = '2.16.840.1.113883.4.349'.freeze
      INTERACTION_ID = '^PN^200VETS^USDVA'.freeze

      def initialize
        @doc = Ox::Document.new(:version => '1.0')
      end

      def header(vcid, extension)
        @message << element('id', root: ROOT_ID, extension: "#{vcid}#{INTERACTION_ID}")
        @message << element('creationTime', value: Time.now.utc.strftime('%Y%m%d%M%H%M%S'))
        @message << element('interactionId', root: ROOT_ID, extension: extension)
        @message << element('processingCode', code: Rails.env.production? ? 'P' : 'D')
        @message << element('processingModeCode', code: 'T')
        @message << element('acceptAckCode', code: 'AL')
        receiver = element('receiver', typeCode: 'RCV')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        id = element('id', root: ROOT_ID)
        device << id
        receiver << device
        @message << receiver
        sender = element('sender', typeCode: 'SND')
        device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
        sender << device
        id = element('id', root: ROOT_ID, extension: SITE_KEY)
        sender << id
        @message << sender
      end

      private

      def element(name, attrs = nil)
        el = Ox::Element.new(name)
        return el unless attrs
        attrs.each { |k, v| k == :text! ? el.replace_text(v) : el[k] = v }
        el
      end

      def xml_tag(operation_id)
        element(operation_id,
          xmlns: 'urn:hl7‐org:v3',
          :'xmlns:ps' => 'http://vaww.oed.oit.va.gov',
          :'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema‐instance",
          :'xsi:schemaLocation' => 'urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/PRPA_IN201305UV02.xsd',
          ITSVersion: 'XML_1.0'
        )
      end
    end
  end
end
