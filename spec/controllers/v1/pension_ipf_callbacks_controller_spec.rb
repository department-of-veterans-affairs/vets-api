# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PensionIpfCallbacksController, type: :controller do
  let(:status) { 'delivered' }
  let(:params) do
    {
      id: '6ba01111-f3ee-4a40-9d04-234asdfb6abab9c',
      reference: nil,
      to: 'test@test.com',
      status:,
      created_at: '2023-01-10T00:04:25.273410Z',
      completed_at: '2023-01-10T00:05:33.255911Z',
      sent_at: '2023-01-10T00:04:25.775363Z',
      notification_type: 'email',
      status_reason: '',
      provider: 'sendgrid'
    }
  end

  describe '#create' do
    before do
      request.headers['Authorization'] = "Bearer #{Settings.pension_ipf_vanotify_status_callback.bearer_token}"
      Flipper.enable(:pension_ipf_callbacks_endpoint)
      allow(PensionIpfNotification).to receive(:create!)
    end

    context 'with payload' do
      context 'if status is delivered' do
        it 'returns success and does not save a record of the payload' do
          post(:create, params:, as: :json)

          expect(PensionIpfNotification).not_to receive(:create!)

          expect(response).to have_http_status(:ok)

          res = JSON.parse(response.body)
          expect(res['message']).to eq 'success'
        end
      end

      context 'if status is a failure that will not retry' do
        let(:status) { 'permanent-failure' }

        it 'returns success' do
          post(:create, params:, as: :json)

          expect(response).to have_http_status(:ok)

          res = JSON.parse(response.body)
          expect(res['message']).to eq 'success'
        end

        context 'and the record failed to save' do
          before do
            allow(PensionIpfNotification).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
          end

          it 'returns failed' do
            post(:create, params:, as: :json)

            expect(response).to have_http_status(:ok)

            res = JSON.parse(response.body)
            expect(res['message']).to eq 'failed'
          end
        end
      end
    end
  end

  describe 'authentication' do
    context 'with missing Authorization header' do
      it 'returns 401' do
        request.headers['Authorization'] = nil
        post(:create, params:, as: :json)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid Authorization header' do
      it 'returns 401' do
        request.headers['Authorization'] = 'Bearer foo'
        post(:create, params:, as: :json)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
