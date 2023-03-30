# frozen_string_literal: true

require 'rails_helper'
require 'emis/messages/edipi_or_icn_message'

describe EMIS::Messages::EdipiOrIcnMessage do
  describe '.to_xml' do
    context 'with an edipi' do
      let(:edipi) { Faker::Number.number(digits: 10).to_s }
      let(:xml) do
        EMIS::Messages::EdipiOrIcnMessage.new(edipi:, request_name: 'foo').to_xml
      end

      it 'includes the edipi' do
        expect(xml).to eq_text_at_path('soap:Body/v11:eMISfoo/v12:edipiORicn/v13:edipiORicnValue[0]', edipi)
      end

      it 'says it includes the EDIPI' do
        expect(xml).to eq_text_at_path('soap:Body/v11:eMISfoo/v12:edipiORicn/v13:inputType[0]', 'EDIPI')
      end
    end

    context 'with an icn' do
      let(:icn) { Faker::Number.number(digits: 10).to_s }
      let(:xml) do
        EMIS::Messages::EdipiOrIcnMessage.new(icn:, request_name: 'foo').to_xml
      end

      it 'includes the icn' do
        expect(xml).to eq_text_at_path('soap:Body/v11:eMISfoo/v12:edipiORicn/v13:edipiORicnValue[0]', icn)
      end

      it 'says it includes the ICN' do
        expect(xml).to eq_text_at_path('soap:Body/v11:eMISfoo/v12:edipiORicn/v13:inputType[0]', 'ICN')
      end
    end

    context 'bad arguments' do
      it 'throws an argument error with neither identifier' do
        expect do
          EMIS::Messages::EdipiOrIcnMessage.new(request_name: 'foo')
        end.to raise_error(ArgumentError, 'must include either an EDIPI or ICN, but not both')
      end

      it 'throws an argument error with both identifiers' do
        expect do
          EMIS::Messages::EdipiOrIcnMessage.new(edipi: 1234, icn: 5678, request_name: 'foo')
        end.to raise_error(ArgumentError, 'must include either an EDIPI or ICN, but not both')
      end
    end
  end
end
