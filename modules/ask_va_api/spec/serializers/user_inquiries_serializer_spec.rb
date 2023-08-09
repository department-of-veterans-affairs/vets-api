# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserInquiriesSerializer do
  let(:user) { DynamicsService.new.get_submitter_inquiries(uuid: '6400bbf301eb4e6e95ccea7693eced6f') }
  let(:response) { described_class.new(user) }
  let(:expected_response) do
    { data: { id: nil,
              type: :user_inquiries,
              attributes: { inquiries: [{ data: { id: nil,
                                                  type: :inquiry,
                                                  attributes: { inquiry_number: 'A-1',
                                                                topic: 'Topic',
                                                                question: 'This is a question',
                                                                processing_status: 'In Progress',
                                                                last_update: '08/07/23' } } },
                                        { data: { id: nil,
                                                  type: :inquiry,
                                                  attributes: { inquiry_number: 'A-2',
                                                                topic: 'Topic',
                                                                question: 'This is a question',
                                                                processing_status: 'In Progress',
                                                                last_update: '08/07/23' } } }] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
