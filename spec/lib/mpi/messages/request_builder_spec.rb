# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/request_builder'

describe MPI::Messages::RequestBuilder do
  describe '#perform' do
    subject { described_class.new(extension:, body:, search_token:).perform }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(random_number)
      allow(IdentitySettings.mvi).to receive(:processing_code).and_return(processing_code)
      Timecop.freeze
    end

    after { Timecop.return }

    let(:extension) { 'some-extension' }
    let(:body) { 'some-body' }
    let(:search_token) { 'some-search-token' }
    let(:random_number) { 'some-random-number' }
    let(:processing_code) { 'some-processing-code' }
    let(:current_time) { Time.now.utc.strftime('%Y%m%d%H%M%S') }
    let(:envelope_component) do
      '<env:Envelope xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" ' \
        'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' \
        'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" ' \
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    end
    let(:instruct_component) do
      '<?xml version="1.0" encoding="utf-8"?>'
    end
    let(:idm_component) do
      "<idm:#{extension} " \
        'xmlns:idm="http://vaww.oed.oit.va.gov" ' \
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema‐instance" ' \
        "xsi:schemaLocation=\"urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/#{extension}.xsd\" " \
        'xmlns="urn:hl7‐org:v3" ' \
        'ITSVersion="XML_1.0">'
    end
    let(:header_component) do
      "<id root=\"1.2.840.114350.1.13.0.1.7.1.1\" extension=\"200VGOV-#{random_number}\"/>
      <creationTime value=\"#{current_time}\"/>
      <versionCode code=\"4.1\"/>
      <interactionId root=\"2.16.840.1.113883.1.6\" extension=\"#{extension}\"/>
      <processingCode code=\"#{processing_code}\"/>
      <processingModeCode code=\"T\"/>
      <acceptAckCode code=\"AL\"/>"
    end
    let(:receiver_component) do
      "<receiver typeCode=\"RCV\">
        <device classCode=\"DEV\" determinerCode=\"INSTANCE\">
          <id root=\"1.2.840.114350.1.13.999.234\" extension=\"200M\"/>
        </device>
      </receiver>"
    end
    let(:sender_component) do
      "<sender typeCode=\"SND\">
        <device classCode=\"DEV\" determinerCode=\"INSTANCE\">
          <id root=\"2.16.840.1.113883.4.349\" extension=\"200VGOV\"/>
        </device>
      </sender>"
    end
    let(:attention_line_component) do
      "<attentionLine>
        <keyWordText>Search.Token</keyWordText>
        <value xsi:type=\"ST\">#{search_token}</value>
      </attentionLine>"
    end

    context 'when search token is set to an arbitrary value' do
      let(:search_token) { 'some-search-token' }

      it 'builds an attention line component with given search token' do
        expect(subject).to include(attention_line_component)
      end
    end

    context 'when search token is nil' do
      let(:search_token) { nil }

      it 'does not build an attention line component' do
        expect(subject).not_to include(attention_line_component)
      end
    end

    it 'builds a message with expected components' do
      request = subject
      expect(request).to include(instruct_component)
      expect(request).to include(envelope_component)
      expect(request.force_encoding('UTF-8')).to include(idm_component)
      expect(request).to include(header_component)
      expect(request).to include(receiver_component)
      expect(request).to include(sender_component)
      expect(request).to include(body)
    end
  end
end
