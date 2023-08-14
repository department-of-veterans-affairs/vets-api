# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Replies::Reply do
  subject(:creator) { described_class }

  let(:info) do
    {
      inquiryNumber: 'A-1',
      replyId: 'R-1',
      reply: 'This is a reply',
      userUuid: '6400bbf301eb4e6e95ccea7693eced6f'
    }
  end
  let(:reply) { creator.new(info) }

  it 'creates an reply' do
    expect(reply).to have_attributes(
      id: 'R-1',
      inquiry_number: 'A-1',
      reply: 'This is a reply'
    )
  end
end
