# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'

describe ClaimsApi::LocalBGS do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  # Testing potential ways the current check could be tricked
  describe '#all' do
    let(:subject_instance) { subject }

    context 'when an error message gets returns unknown' do
      it 'the soap error handler returns unprocessable' do
        allow(subject_instance).to receive(:make_request).with(endpoint: 'PersonWebServiceBean/PersonWebService',
                                                               action: 'findPersonBySSN',
                                                               body: Nokogiri::XML::DocumentFragment.new(
                                                                 Nokogiri::XML::Document.new
                                                               ),
                                                               key: 'PersonDTO').and_return(:bgs_unknown_error_message)
        begin
          allow(soap_error_handler).to receive(:handle_errors)
            .with(:bgs_unknown_error_message).and_raise(Common::Exceptions::UnprocessableEntity)
          ret = soap_error_handler.send(:handle_errors, :bgs_unknown_error_message)
          expect(ret.class).to_be Array
          expect(ret.size).to eq 1
        rescue => e
          expect(e.message).to include 'Unprocessable Entity'
        end
      end
    end
  end

  describe '#safe_xml' do
    let(:subject_instance) { subject }

    it 'returns the original content when XML parsing fails' do
      invalid_inputs = ['invalid xml', '{not: xml}', '<incomplete>xml', nil]
      
      invalid_inputs.each do |input|
        expect(subject_instance.safe_xml(input)).to eq(input)
      end
    end

    it 'converts valid XML to a stringified hash' do
      valid_xml = '<?xml version="1.0" encoding="UTF-8"?><root><child>value</child></root>'
      result = subject_instance.safe_xml(valid_xml)
      
      expect(result).to be_a(String)
      expect(result).to include('"root"=>')
      expect(result).to include('"child"=>"value"')
    end

    it 'preserves nested structure in the hash representation' do
      nested_xml = '<?xml version="1.0" encoding="UTF-8"?><root><parent><child>value</child></parent></root>'
      result = subject_instance.safe_xml(nested_xml)
      
      expect(result).to be_a(String)
      parsed = JSON.parse(result.gsub("=>", ":").gsub(":nil,", ":null,"))
      expect(parsed['root']['parent']['child']).to eq('value')
    end
  end
end
