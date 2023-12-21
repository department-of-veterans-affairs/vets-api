# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicsMockService do
  let(:endpoint) { 'get_inquiries_mock_data' }
  let(:method) { 'GET' }
  let(:payload) { {} }
  let(:service) { described_class.new(icn: nil, logger: nil) }
  let(:file_path) { "modules/ask_va_api/config/locales/#{endpoint.tr('/', '_')}.json" }

  describe '#call' do
    context 'when the file does not exist' do
      before do
        allow(File).to receive(:read).with(file_path).and_raise(Errno::ENOENT)
      end

      it 'raises FileNotFound error' do
        expect do
          service.call(endpoint:)
        end.to raise_error(DynamicsMockService::FileNotFound, "Mock file not found for #{endpoint}")
      end
    end

    context 'when the file contains invalid JSON content' do
      before do
        allow(File).to receive(:read).with(file_path).and_return('invalid_json')
      end

      it 'raises InvalidJSONContent error' do
        expect do
          service.call(endpoint:)
        end.to raise_error(DynamicsMockService::InvalidJSONContent, "Invalid JSON content for #{endpoint}")
      end
    end

    context 'when the file contains valid JSON content' do
      let(:expected_result) do
        {
          icn: '1008709396V637156',
          id: '1',
          inquiryNumber: 'A-1',
          inquiryStatus: 'In Progress',
          submitterQuestion: 'What is my status?',
          lastUpdate: '12/20/23',
          inquiryHasAttachments: true,
          inquiryHasBeenSplit: true,
          veteranRelationship: 'self',
          schoolFacilityCode: '0123',
          inquiryTopic: 'Status of a pending claim',
          inquiryLevelOfAuthentication: 'Personal',
          attachmentNames: [
            {
              id: '1',
              name: 'testfile.txt'
            }
          ]
        }
      end

      context 'with inquiry_number payload' do
        let(:payload) { { inquiry_number: 'A-1' } }

        it 'filters data based on inquiry number' do
          expect(service.call(endpoint:, payload:)).to eq(expected_result)
        end

        context 'with non-existent inquiry_number' do
          let(:payload) { { inquiry_number: 99 } }

          it 'returns an empty hash' do
            expect(service.call(endpoint:, payload:)).to eq({})
          end
        end
      end

      context 'with icn payload' do
        let(:payload) { { icn: '1008709396V637156' } }

        it 'filters data based on icn and excludes attachments' do
          expect(service.call(endpoint:, payload:).first).to eq(expected_result)
        end
      end
    end
  end
end
