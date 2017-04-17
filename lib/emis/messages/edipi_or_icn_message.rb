# frozen_string_literal: true
require 'ox'

module EMIS
  module Messages
    class EdipiOrIcnMessage
      attr_reader :edipi
      attr_reader :icn

      def initialize(edipi: nil, icn: nil)
        if (edipi.present? && icn.present?) || (edipi.nil? && icn.nil?)
          raise ArgumentError, 'must include either an EDIPI or ICN, but not both'
        end
        @edipi = edipi
        @icn = icn
      end

      def to_xml
        header = build_header
        body = build_body
        envelope = build_envelope
        envelope << header
        envelope << body
        doc = Ox::Document.new(version: '1.0')
        doc << envelope
        Ox.dump(doc)
      end

      private

      def element(name, attrs = {})
        Ox::Element.new(name).tap do |el|
          attrs.each { |k, v| k == :text! ? el.replace_text(v) : el[k] = v }
        end
      end

      def build_header
        element('env:Header').tap do |header|
          header << element('v1:inputHeaderInfo').tap do |hi|
            hi << element('v1:userId', text!: 'vets.gov')
            hi << element('v1:sourceSystemName', text!: 'vets.gov')
            hi << element('v1:transactionId', text!: SecureRandom.uuid)
          end
        end
      end

      def build_body
        edipi_or_icn = element('v12:edipiORicn')
        edipi_or_icn << element('v13:edipiORicnValue', text!: @edipi || @icn)
        edipi_or_icn << element('v13:inputType', text!: (@edipi && 'EDIPI') || (@icn && 'ICN'))
        element('env:Body').tap do |body|
          body << edipi_or_icn
        end
      end

      def build_envelope
        element('env:Envelope', Settings.emis.soap_namespaces)
      end
    end
  end
end
