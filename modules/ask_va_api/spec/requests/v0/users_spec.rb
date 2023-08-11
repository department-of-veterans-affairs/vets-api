# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ask_va_api/v0/users', type: :request do
  describe '#index' do
    let(:authorized_user) do
      build(:user, :loa3, { email: 'vets.gov.user+228@gmail.com', uuid: '6400bbf301eb4e6e95ccea7693eced6f' })
    end
    let(:unauthorized_user) { build(:user, :loa3, { email: 'vets.gov.user8@gmail.com' }) }
    let(:json_response) do
      { 'data' =>
        { 'id' => nil,
          'type' => 'user_inquiries',
          'attributes' =>
          { 'inquiries' =>
            [{ 'data' =>
               { 'id' => nil,
                 'type' => 'inquiry',
                 'attributes' =>
                 { 'attachments' => nil,
                   'inquiry_number' => 'A-1',
                   'topic' => 'Topic',
                   'question' => 'This is a question',
                   'processing_status' => 'In Progress',
                   'last_update' => '08/07/23' } } },
             { 'data' =>
               { 'id' => nil,
                 'type' => 'inquiry',
                 'attributes' =>
                 { 'attachments' => nil,
                   'inquiry_number' => 'A-2',
                   'topic' => 'Topic',
                   'question' => 'This is a question',
                   'processing_status' => 'In Progress',
                   'last_update' => '08/07/23' } } }] } } }
    end

    context 'when the user is signed in' do
      before do
        sign_in(authorized_user)
        get '/ask_va_api/v0/users/dashboard'
      end

      it 'returns http status 200 :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the correct data' do
        expect(JSON.parse(response.body)).to eq(json_response)
      end
    end

    context 'when the user is not signed in' do
      before do
        get '/ask_va_api/v0/users/dashboard'
      end

      it 'returns http status 401 :ok' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
