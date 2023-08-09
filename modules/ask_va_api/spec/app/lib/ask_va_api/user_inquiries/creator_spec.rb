# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::UserInquiries::Creator do
  subject(:creator) { described_class }

  let(:info) do
    [{
      'inquiryNumber' => 'A-1',
      'inquiryTopic' => 'Topic',
      'submitterQuestions' => 'This is a question',
      'inquiryProcessingStatus' => 'In Progress',
      'lastUpdate' => '08/07/23',
      'userUuid' => '6400bbf301eb4e6e95ccea7693eced6f'
    }]
  end
  let(:user_inquiries) { creator.new(info) }

  it 'creates a user_inquiries object' do
    expect(user_inquiries).to have_attributes(id: nil,
                                              inquiries: info)
  end
end
