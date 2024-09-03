# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Serializer do
  let(:file_path) { 'modules/ask_va_api/config/locales/get_replies_mock_data.json' }
  let(:data) { JSON.parse(File.read(file_path), symbolize_names: true)[:Data] }
  let(:cor1) { AskVAApi::Correspondences::Entity.new(data.first) }
  let(:cor2) { AskVAApi::Correspondences::Entity.new(data.last) }
  let(:response) { described_class.new([cor1]) }
  let(:expected_response) do
    {  data: [{ id: '1', type: :correspondence,
                attributes: {
                  message_type: '722310001: Response from VA',
                  created_on: '1/2/23 4:45:45 PM',
                  modified_on: '1/2/23 5:45:45 PM',
                  status_reason: 'Completed/Sent',
                  description: 'Your claim is still In Progress',
                  enable_reply: true,
                  attachments: [{ Id: '12',
                                  Name: 'correspondence_1_attachment.pdf' }]
                } }] }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
