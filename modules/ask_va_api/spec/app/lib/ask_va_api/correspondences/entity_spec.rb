# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      inquiryNumber: 'A-1',
      replyId: 'R-1',
      reply: 'This is a reply',
      secId: '6400bbf301eb4e6e95ccea7693eced6f'
    }
  end
  let(:correspondence) { creator.new(info) }

  it 'creates an correspondence' do
    expect(correspondence).to have_attributes(
      id: 'R-1',
      inquiry_number: 'A-1',
      correspondence: 'This is a reply'
    )
  end
end
