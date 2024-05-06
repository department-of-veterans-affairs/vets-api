# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pega callback', type: :request do
  before do
    allow_any_instance_of(IvcChampva::V1::PegaController).to receive(:authenticate_service_account).and_return(true)
  end

  describe 'POST #update_status' do
    let(:valid_payload) do
      {
        form_uuid: '12345678-1234-5678-1234-567812345678',
        file_names: ['file1.pdf', 'file2.pdf'],
        status: 'processed'
      }
    end

    context 'with valid payload' do
      it 'returns HTTP status 200' do
        post '/ivc_champva/v1/forms/status_updates', params: valid_payload
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid payload' do
      let(:invalid_payload) { { status: 'invalid' } }

      it 'returns HTTP status 200' do
        post '/ivc_champva/v1/forms/status_updates', params: invalid_payload
        expect(response).to have_http_status(:ok)
      end

      it 'returns an error message' do
        post '/ivc_champva/v1/forms/status_updates', params: invalid_payload
        expect(response.body).to include('error')
      end
    end
  end
end
