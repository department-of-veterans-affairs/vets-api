# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicsMockService do
  let(:endpoint) { 'some/endpoint' }
  let(:method) { 'GET' }
  let(:criteria) { {} }
  let(:service) { described_class.new(endpoint, method, criteria) }
  let(:file_path) { "modules/ask_va_api/config/locales/#{endpoint.tr('/', '_')}.json" }

  describe '#call' do
    context 'when the file does not exist' do
      before do
        allow(File).to receive(:read).with(file_path).and_raise(Errno::ENOENT)
      end

      it 'raises FileNotFound error' do
        expect do
          service.call
        end.to raise_error(DynamicsMockService::FileNotFound, "Mock file not found for #{endpoint}")
      end
    end

    context 'when the file contains invalid JSON content' do
      before do
        allow(File).to receive(:read).with(file_path).and_return('invalid_json')
      end

      it 'raises InvalidJSONContent error' do
        expect do
          service.call
        end.to raise_error(DynamicsMockService::InvalidJSONContent, "Invalid JSON content for #{endpoint}")
      end
    end

    context 'when the file contains valid JSON content' do
      let(:mock_data) { { data: [{ inquiryNumber: 1, sec_id: 10, attachments: {} }] } }
      let(:json_content) { JSON.generate(mock_data) }

      before do
        allow(File).to receive(:read).with(file_path).and_return(json_content)
      end

      context 'with inquiry_number criteria' do
        let(:criteria) { { inquiry_number: 1 } }

        it 'filters data based on inquiry number' do
          expect(service.call).to eq(mock_data[:data].first)
        end

        context 'with non-existent inquiry_number' do
          let(:criteria) { { inquiry_number: 2 } }

          it 'returns an empty hash' do
            expect(service.call).to eq({})
          end
        end
      end

      context 'with sec_id criteria' do
        let(:criteria) { { sec_id: 10 } }

        it 'filters data based on sec_id and excludes attachments' do
          expected_result = mock_data[:data].map { |i| i.except(:attachments) }
          expect(service.call).to eq(expected_result)
        end
      end

      context 'without specific criteria' do
        it 'returns the full mock data' do
          expect(service.call).to eq(mock_data[:data])
        end
      end
    end
  end
end
