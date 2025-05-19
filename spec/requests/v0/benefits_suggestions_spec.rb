require 'rails_helper'

RSpec.describe 'V0::BenefitsSuggestions', type: :request do
  describe 'POST /v0/benefits_suggestions' do
    let(:valid_params) do
      {
        completed_form_id: '10-10EZ',
        submitted_data: {
          _meta: { relationship_to_veteran: 'spouse' },
          veteranInfo: { vaCompensationType: 'highDisability' }
        }
      }
    end
    let(:mock_service_instance) { instance_double(FormEligibility::FormConnectorService) }
    let(:mock_suggestions) { [{ 'suggestion_id' => '1', 'text' => 'Mock Suggestion 1' }] }

    before do
      allow(FormEligibility::FormConnectorService).to receive(:new).and_return(mock_service_instance)
    end

    context 'with valid parameters' do
      before do
        allow(mock_service_instance).to receive(:suggest_forms)
          .with(valid_params[:completed_form_id], valid_params[:submitted_data].deep_stringify_keys) # Service expects string keys
          .and_return(mock_suggestions)
      end

      it 'returns a 200 OK status and the suggestions' do
        post '/v0/benefits_suggestions', params: valid_params
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['suggestions']).to eq(mock_suggestions)
      end
    end

    context 'when completed_form_id is missing' do
      it 'returns a 400 Bad Request status with an error message' do
        post '/v0/benefits_suggestions', params: { submitted_data: { foo: 'bar' } }
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['title']).to eq('Parameter Missing')
        expect(json_response['errors'].first['detail']).to include("param is missing or the value is empty: completed_form_id")
      end
    end

    context 'when submitted_data is missing' do
      # The controller defaults submitted_data to {}, so the service should receive that.
      before do
        allow(mock_service_instance).to receive(:suggest_forms)
          .with(valid_params[:completed_form_id], {}) # Expecting empty hash
          .and_return(mock_suggestions)
      end

      it 'returns a 200 OK status and suggestions based on empty submitted_data' do
        post '/v0/benefits_suggestions', params: { completed_form_id: valid_params[:completed_form_id] }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['suggestions']).to eq(mock_suggestions)
      end
    end
    
    context 'when the service raises an ArgumentError' do
      before do
        allow(mock_service_instance).to receive(:suggest_forms)
          .and_raise(ArgumentError.new("Service exploded"))
      end

      it 'returns a 400 Bad Request status with the service error message' do
        post '/v0/benefits_suggestions', params: valid_params
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        expect(json_response['errors'].first['title']).to eq('Argument Error')
        expect(json_response['errors'].first['detail']).to eq('Service exploded')
      end
    end
  end
end 