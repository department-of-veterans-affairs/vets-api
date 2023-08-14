# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ask_va_api/v0/inquiries', type: :request do
  describe '#show' do
    let(:user) do
      build(:user, :loa3, { email: 'vets.gov.user+228@gmail.com', uuid: '6400bbf301eb4e6e95ccea7693eced6f' })
    end
    let(:inquiry_number) { 'A-1' }
    let(:expected_response) do
      { 'data' => { 'id' => nil,
                    'type' => 'inquiry',
                    'attributes' => { 'attachments' => [{ 'activity' => 'activity_1', 'date_sent' => '08/7/23' }],
                                      'inquiry_number' => 'A-1',
                                      'topic' => 'Topic',
                                      'question' => 'When is Sergeant Joe Smith birthday?',
                                      'processing_status' => 'Close',
                                      'last_update' => '08/07/23',
                                      'reply' => {
                                        'data' => {
                                          'id' => 'R-1',
                                          'type' => 'reply',
                                          'attributes' => {
                                            'inquiry_number' => 'A-1',
                                            'reply' => 'Sergeant Joe Smith birthday is July 4th, 1980'
                                          }
                                        }
                                      } } } }
    end
    let(:parsed_response) { JSON.parse(response.body) }

    before do
      sign_in(user)
      get "/ask_va_api/v0/inquiries/#{inquiry_number}"
    end

    context 'when successful' do
      it 'returns a single inquiry' do
        expect(response).to have_http_status(:ok)
        expect(parsed_response).to include(expected_response)
      end
    end

    context 'when not successful' do
      let(:inquiry_number) { 'A-9' }

      it 'returns a single inquiry' do
        expect(response).to have_http_status(:not_found)
        expect(parsed_response).to eq({ 'error' => 'Record with Inquiry Number: A-9 is invalid.' })
      end
    end
  end
end
