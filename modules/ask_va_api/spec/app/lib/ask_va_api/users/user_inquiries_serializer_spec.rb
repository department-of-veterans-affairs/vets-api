# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Users::UserInquiriesSerializer do
  let(:inquiries) { AskVAApi::Users::UserInquiriesCreator.new(uuid: '6400bbf301eb4e6e95ccea7693eced6f').call }
  let(:response) { described_class.new(inquiries) }
  let(:expected_response) do
    { data: { id: nil,
              type: :user_inquiries,
              attributes: { inquiries: [{ data: { id: nil,
                                                  type: :inquiry,
                                                  attributes: { attachments: nil,
                                                                inquiry_number: 'A-1',
                                                                topic: 'Topic',
                                                                question: 'When is Sergeant Joe Smith birthday?',
                                                                processing_status: 'Close',
                                                                last_update: '08/07/23',
                                                                reply: {
                                                                  data: nil
                                                                } } } },
                                        { data: { id: nil,
                                                  type: :inquiry,
                                                  attributes: { attachments: nil,
                                                                inquiry_number: 'A-2',
                                                                topic: 'Topic',
                                                                question: 'How long was Sergeant Joe Smith' \
                                                                          ' overseas for?',
                                                                processing_status: 'In Progress',
                                                                last_update: '08/07/23',
                                                                reply: {
                                                                  data: nil
                                                                } } } }] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
