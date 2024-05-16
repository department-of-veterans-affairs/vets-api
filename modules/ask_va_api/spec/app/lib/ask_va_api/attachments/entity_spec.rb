# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      Id: '1',
      FileContent: 'SGVsbG8sIHRoaXMgaXMgYSB0ZXN0IGZpbGUgZm9yIGRvd25sb2FkaW5nIQ==',
      FileName: 'testfile.txt'
    }
  end
  let(:attachment) { creator.new(info) }

  it 'creates an attachment' do
    expect(attachment).to have_attributes({
                                            id: info[:Id],
                                            file_content: info[:FileContent],
                                            file_name: info[:FileName]
                                          })
  end
end
