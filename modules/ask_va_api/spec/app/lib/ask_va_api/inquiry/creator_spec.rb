# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiry::Creator do
  subject(:creator) { described_class }

  let(:info) do
    {
      'inquiryNumber' => 'A-1',
      'inquiryTopic' => 'Topic',
      'submitterQuestions' => 'This is a question',
      'inquiryProcessingStatus' => 'In Progress',
      'lastUpdate' => '08/07/23',
      'userUuid' => '6400bbf301eb4e6e95ccea7693eced6f'
    }
  end
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({
                                         inquiry_number: 'A-1',
                                         topic: 'Topic',
                                         question: 'This is a question',
                                         processing_status: 'In Progress',
                                         last_update: '08/07/23'
                                       })
  end
end
