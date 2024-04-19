# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      Id: '1',
      ModifiedOn: '1/2/23',
      StatusReason: 'Completed/Sent',
      Description: 'Your claim is still In Progress',
      MessageType: '722310001: Response from VA',
      EnableReply: true,
      AttachmentNames: [
        {
          id: '12',
          name: 'correspondence_1_attachment.pdf'
        }
      ]
    }
  end
  let(:correspondence) { creator.new(info) }

  it 'creates an correspondence' do
    expect(correspondence).to have_attributes(
      id: info[:Id],
      modified_on: info[:ModifiedOn],
      status_reason: info[:StatusReason],
      description: info[:Description],
      message_type: info[:MessageType],
      enable_reply: true,
      attachments: [
        {
          id: info[:AttachmentNames].first[:id],
          name: info[:AttachmentNames].first[:name]
        }
      ]
    )
  end
end
