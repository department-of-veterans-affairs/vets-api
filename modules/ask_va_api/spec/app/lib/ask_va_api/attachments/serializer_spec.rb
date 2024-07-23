# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Serializer do
  let(:info) do
    {
      Id: '1',
      FileContent: 'SGVsbG8sIHRoaXMgaXMgYSB0ZXN0IGZpbGUgZm9yIGRvd25sb2FkaW5nIQ==',
      FileName: 'testfile.txt'
    }
  end
  let(:attachment) { AskVAApi::Attachments::Entity.new(info) }

  let(:response) { described_class.new(attachment) }
  let(:expected_response) do
    { data: { id: '1',
              type: :attachment,
              attributes: { file_content: info[:FileContent],
                            file_name: info[:FileName] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
