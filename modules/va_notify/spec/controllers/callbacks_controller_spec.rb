require 'rails_helper'

RSpec.describe VANotify::CallbacksController, type: :controller do
  describe 'POST #create' do
    let(:valid_params) do
      {
        va_notify_notification: {
          notification_id: '12345',
          reference: 'ref123',
          to: 'test@example.com',
          status: 'delivered'
        }
      }
    end

    let(:invalid_params) do
      {
        va_notify_notification: {
          notification_id: '',
          reference: '',
          to: '',
          status: ''
        }
      }
    end

    before do
      allow(controller).to receive(:authenticate_callback).and_return(true)
    end

    context 'with valid params' do
      it 'creates a new notification and returns success' do
        expect {
          post :create, params: valid_params
        }.to change(VANotify::Notification, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('success')
      end
    end

    context 'with invalid params' do
      it 'returns an error for missing required fields' do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['message']).to eq('Missing required fields')
      end
    end
  end

  describe 'authentication' do
    it 'returns unauthorized if authentication fails' do
      allow(controller).to receive(:authenticate_callback).and_return(false)

      post :create, params: valid_params

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['message']).to eq('Unauthorized')
    end
  end
end
