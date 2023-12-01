# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      inquiryId: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
      id: '123456-asdf-456',
      modifiedon: '1/2/23',
      status_reason: 'Completed/Sent',
      description: 'description',
      message_type: 'Sergeant Joe Smith birthday is July 4th, 1980',
      enable_reply: true,
      attachmentNames: [
        {
          id: '012345',
          name: 'File A.pdf'
        }
      ]
    }
  end
  let(:correspondence) { creator.new(info) }

  it 'creates an correspondence' do
    expect(correspondence).to have_attributes(
      inquiry_id: info[:inquiryId],
      id: info[:id],
      modified_on: info[:modifiedon],
      status_reason: info[:status_reason],
      description: info[:description],
      message: info[:message_type],
      enable_reply: true,
      attachment_names: [
        {
          id: info[:attachmentNames].first[:id],
          name: info[:attachmentNames].first[:name]
        }
      ]
    )
  end
end
