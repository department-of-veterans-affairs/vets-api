# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Serializer do
  let(:info) do
    {
      id: '1',
      fileContent: 'SGVsbG8sIHRoaXMgaXMgYSB0ZXN0IGZpbGUgZm9yIGRvd25sb2FkaW5nIQ==',
      fileName: 'testfile.txt'
    }
  end
  let(:attachment) { AskVAApi::Attachments::Entity.new(info) }

  let(:response) { described_class.new(attachment) }
  let(:expected_response) do
    { data: { id: '1',
              type: :attachment,
              attributes: { file_content: info[:fileContent],
                            file_name: info[:fileName] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
