# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      inquiryId: '1',
      id: '1',
      modifiedon: '1/2/23',
      status_reason: 'Completed/Sent',
      description: 'Your claim is still In Progress',
      message_type: '722310001: Response from VA',
      enable_reply: true,
      attachmentNames: [
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
      inquiry_id: info[:inquiryId],
      id: info[:id],
      modified_on: info[:modifiedon],
      status_reason: info[:status_reason],
      description: info[:description],
      message_type: info[:message_type],
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
