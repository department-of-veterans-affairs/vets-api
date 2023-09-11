# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Serializer do
  let(:info) do
    {
      inquiryNumber: 'A-1',
      inquiryTopic: 'Topic',
      submitterQuestions: 'This is a question',
      inquiryProcessingStatus: 'In Progress',
      lastUpdate: '08/07/23',
      userUuid: '6400bbf301eb4e6e95ccea7693eced6f'
    }
  end
  let(:inquiry) { AskVAApi::Inquiries::Inquiry.new(info) }
  let(:response) { described_class.new(inquiry) }
  let(:expected_response) do
    { data: { id: nil,
              type: :inquiry,
              attributes: { attachments: nil,
                            inquiry_number: 'A-1',
                            topic: 'Topic',
                            question: 'This is a question',
                            processing_status: 'In Progress',
                            last_update: '08/07/23',
                            reply: {
                              data: nil
                            } } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
