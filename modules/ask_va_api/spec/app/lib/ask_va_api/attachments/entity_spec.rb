# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      id: '1',
      fileContent: 'SGVsbG8sIHRoaXMgaXMgYSB0ZXN0IGZpbGUgZm9yIGRvd25sb2FkaW5nIQ==',
      fileName: 'testfile.txt'
    }
  end
  let(:attachment) { creator.new(info) }

  it 'creates an attachment' do
    expect(attachment).to have_attributes({
                                            id: info[:id],
                                            file_content: info[:fileContent],
                                            file_name: info[:fileName]
                                          })
  end
end
