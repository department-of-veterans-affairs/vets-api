# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Serializer do
  let(:file_path) { 'modules/ask_va_api/config/locales/get_replies_mock_data.json' }
  let(:data) { JSON.parse(File.read(file_path), symbolize_names: true)[:data] }
  let(:cor1) { AskVAApi::Correspondences::Entity.new(data.first) }
  let(:cor2) { AskVAApi::Correspondences::Entity.new(data.last) }
  let(:response) { described_class.new([cor1, cor2]) }
  let(:expected_response) do
    { data: [{ id: '123456-asdf-456',
               type: :correspondence,
               attributes: { inquiry_id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
                             message: 'Sergeant Joe Smith birthday is July 4th, 1980',
                             modified_on: '1/2/23',
                             status_reason: 'Completed/Sent',
                             description: 'description',
                             enable_reply: true,
                             attachment_names: [{ id: '012345', name: 'File A.pdf' }] } },
             { id: '09876-asdf-123',
               type: :correspondence,
               attributes: { inquiry_id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
                             message: 'What is your question?',
                             modified_on: '1/2/23',
                             status_reason: 'Completed/Sent',
                             description: 'description',
                             enable_reply: true,
                             attachment_names: nil } }] }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
