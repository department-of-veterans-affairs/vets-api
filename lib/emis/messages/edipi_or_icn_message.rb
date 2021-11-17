# frozen_string_literal: true

require 'ox'

module EMIS
  module Messages
    # SOAP XML Message to be sent to EMIS API which contains
    # user identifier data
    class EdipiOrIcnMessage
      # User's Electronic Data Interchange Personal Identifier
      attr_reader :edipi
      # User's Integration Control Number
      attr_reader :icn

      # Create a new EdipiOrIcnMessage
      #
      # @param edipi [String] User's Electronic Data Interchange Personal Identifier
      # @param icn [String] User's Integration Control Number
      # @param request_name [String] Request name used in XML request body
      # @param custom_namespaces [Hash] Namespace for API to be called
      def initialize(request_name:, edipi: nil, icn: nil, custom_namespaces: {})
        if (edipi.present? && icn.present?) || (edipi.nil? && icn.nil?)
          raise ArgumentError, 'must include either an EDIPI or ICN, but not both'
        end

        @edipi = edipi
        @icn = icn
        @request_name = request_name
        @custom_namespaces = custom_namespaces
      end

      # Creates XML request body
      # @return [String] XML request body
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
        element('soap:Header').tap do |header|
          header << element('v1:inputHeaderInfo').tap do |hi|
            hi << element('v1:userId', text!: 'vets.gov')
            hi << element('v1:sourceSystemName', text!: 'vets.gov')
            hi << element('v1:transactionId', text!: SecureRandom.uuid)
          end
        end
      end

      def build_body
        request = element("v11:eMIS#{@request_name}")
        edipi_or_icn = element('v12:edipiORicn')
        edipi_or_icn << element('v13:edipiORicnValue', text!: @edipi || @icn)
        edipi_or_icn << element('v13:inputType', text!: (@edipi && 'EDIPI') || (@icn && 'ICN'))
        request << edipi_or_icn
        element('soap:Body').tap do |body|
          body << request
        end
      end

      def build_envelope
        namespaces = Settings.emis.soap_namespaces.to_hash.merge(@custom_namespaces)
        element('soap:Envelope', namespaces)
      end
    end
  end
end
