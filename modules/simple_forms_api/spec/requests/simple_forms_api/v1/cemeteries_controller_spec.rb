# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::V1::CemeteriesController, type: :request do
  describe 'GET /simple_forms_api/v1/cemeteries' do
    context 'when cemeteries data exists' do
      let(:mock_cemetery_data) do
        [
          {
            'id' => '915',
            'type' => 'preneeds_cemeteries',
            'attributes' => {
              'cemetery_id' => '915',
              'name' => 'ABRAHAM LINCOLN NATIONAL CEMETERY',
              'cemetery_type' => 'N',
              'num' => '915'
            }
          },
          {
            'id' => '944',
            'type' => 'preneeds_cemeteries',
            'attributes' => {
              'cemetery_id' => '944',
              'name' => 'CALVERTON NATIONAL CEMETERY',
              'cemetery_type' => 'N',
              'num' => '944'
            }
          }
        ]
      end

      before do
        allow(SimpleFormsApi::CemeteryService).to receive(:all).and_return(mock_cemetery_data)
      end

      it 'returns successful response with cemetery data' do
        get '/simple_forms_api/v1/cemeteries'

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end

      it 'returns properly formatted cemetery data' do
        get '/simple_forms_api/v1/cemeteries'

        json_response = response.parsed_body
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].length).to eq(2)

        first_cemetery = json_response['data'].first
        expect(first_cemetery['id']).to eq('915')
        expect(first_cemetery['type']).to eq('preneeds_cemeteries')
        expect(first_cemetery['attributes']['name']).to eq('ABRAHAM LINCOLN NATIONAL CEMETERY')
        expect(first_cemetery['attributes']['cemetery_type']).to eq('N')
      end

      it 'calls the cemetery service' do
        expect(SimpleFormsApi::CemeteryService).to receive(:all).once

        get '/simple_forms_api/v1/cemeteries'
      end
    end

    context 'when service returns empty array' do
      before do
        allow(SimpleFormsApi::CemeteryService).to receive(:all).and_return([])
      end

      it 'returns empty data array' do
        get '/simple_forms_api/v1/cemeteries'

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['data']).to eq([])
      end
    end

    context 'when service raises an error' do
      before do
        allow(SimpleFormsApi::CemeteryService).to receive(:all).and_raise(StandardError.new('Service error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'handles service errors gracefully' do
        expect { get '/simple_forms_api/v1/cemeteries' }.not_to raise_error
      end
    end
  end
end
