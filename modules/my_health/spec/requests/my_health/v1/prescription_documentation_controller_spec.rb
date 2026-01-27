# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MyHealth::V1::PrescriptionDocumentation', type: :request do
  let(:user) { build(:user, :mhv) }
  let(:prescription_id) { '12345' }
  let(:ndc_number) { '00378-6155-10' }

  let(:rx_details) do
    double(
      'RxDetails',
      cmop_ndc_value: ndc_number
    )
  end

  let(:documentation_response) do
    {
      data: '<html><body>Drug information here</body></html>'
    }
  end

  let(:client) { double('RxClient') }

  before do
    sign_in_as(user)
    allow(Rx::Client).to receive(:new).and_return(client)
  end

  describe 'GET /my_health/v1/prescriptions/:id/documentation' do
    context 'when successful' do
      before do
        allow(client).to receive(:authenticate)
        allow(client).to receive(:get_rx_details).with(prescription_id).and_return(rx_details)
        allow(client).to receive(:get_rx_documentation).with(ndc_number).and_return(documentation_response)
      end

      it 'returns prescription documentation' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['attributes']['html']).to include('Drug information here')
      end

      it 'calls client.get_rx_details with the prescription id' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(client).to have_received(:get_rx_details).with(prescription_id)
      end

      it 'calls client.get_rx_documentation with the NDC number' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(client).to have_received(:get_rx_documentation).with(ndc_number)
      end
    end

    context 'when prescription is not found' do
      before do
        allow(client).to receive(:authenticate)
        allow(client).to receive(:get_rx_details).with(prescription_id).and_return(nil)
      end

      it 'returns not found error' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to include(prescription_id)
      end
    end

    context 'when NDC number is missing' do
      let(:rx_without_ndc) do
        double('RxDetails', cmop_ndc_value: nil)
      end

      before do
        allow(client).to receive(:authenticate)
        allow(client).to receive(:get_rx_details).with(prescription_id).and_return(rx_without_ndc)
      end

      it 'returns unprocessable entity error' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to include('NDC')
      end
    end

    context 'when upstream service fails' do
      before do
        allow(client).to receive(:authenticate)
        allow(client).to receive(:get_rx_details).with(prescription_id).and_return(rx_details)
      end

      it 'returns error when service is unavailable' do
        allow(client).to receive(:get_rx_documentation)
          .and_raise(Common::Exceptions::BackendServiceException.new)

        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(response).not_to have_http_status(:ok)
      end
    end

    context 'when documentation data is empty' do
      let(:empty_documentation_response) do
        { data: nil }
      end

      before do
        allow(client).to receive(:authenticate)
        allow(client).to receive(:get_rx_details).with(prescription_id).and_return(rx_details)
        allow(client).to receive(:get_rx_documentation).with(ndc_number).and_return(empty_documentation_response)
      end

      it 'returns prescription documentation with nil html' do
        get "/my_health/v1/prescriptions/#{prescription_id}/documentation"

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['attributes']['html']).to be_nil
      end
    end
  end
end
