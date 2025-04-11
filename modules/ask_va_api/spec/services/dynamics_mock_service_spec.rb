# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicsMockService do
  let(:endpoint) { 'inquiries' }
  let(:method) { 'GET' }
  let(:payload) { {} }
  let(:service) { described_class.new(icn: nil, logger: nil) }
  let(:file_path) { "modules/ask_va_api/config/locales/get_#{endpoint}_mock_data.json" }

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
        { Data: { SubmitterICN: I18n.t('ask_va_api.test_users.test_user_119_icn'),
                  Id: '1',
                  CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
                  CreatedOn: '8/5/2024 4:51:52 PM',
                  InquiryNumber: 'A-1',
                  InquiryStatus: 'Replied',
                  SubmitterQuestion: 'What is my status?',
                  LastUpdate: '8/5/2024 4:51:52 PM',
                  QueueId: '987654',
                  QueueName: 'Debt Management Center',
                  InquiryHasAttachments: true,
                  InquiryHasBeenSplit: true,
                  VeteranRelationship: 'self',
                  SchoolFacilityCode: '0123',
                  InquiryTopic: 'Status of a pending claim',
                  InquiryLevelOfAuthentication: 'Personal',
                  AttachmentNames: [{ Id: '1', Name: 'testfile.txt' }] } }
      end

      context 'with id payload' do
        let(:payload) { { id: '1' } }

        it 'filters data based on id' do
          expect(service.call(endpoint:, payload:)).to eq(expected_result)
        end
      end

      context 'with icn payload' do
        let(:test_users) { I18n.t('ask_va_api.test_users') }
        let(:icn) do
          test_users['test_user_119_icn']
        end

        it 'filters data based on icn and excludes attachments' do
          expect(service.call(endpoint:, payload:).first).to eq(expected_result[:Data])
        end
      end
    end
  end
end
