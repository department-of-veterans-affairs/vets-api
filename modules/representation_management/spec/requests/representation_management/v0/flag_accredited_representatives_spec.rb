# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::FlagAccreditedRepresentatives', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/flag_accredited_representatives' }

    context 'when submitting a single valid flag' do
      let(:single_valid_flag_params) do
        {
          representative_id: '1',
          flags: [{ flag_type: 'email', flagged_value: 'example@email.com' }]
        }
      end

      it 'successfully creates a FlaggedVeteranRepresentativeContactData record' do
        expect { post base_path, params: single_valid_flag_params }
          .to change(RepresentationManagement::FlaggedVeteranRepresentativeContactData, :count).by(1)
      end

      it 'responds with a created status' do
        post base_path, params: single_valid_flag_params
        expect(response).to have_http_status(:created)
      end

      it 'returns the correct serialized data' do
        post base_path, params: single_valid_flag_params
        json_response_data = JSON.parse(response.body)['data']
        expect(json_response_data).to be_an(Array)

        flag_object = json_response_data.first
        expect(flag_object).to include('id', 'type', 'attributes')

        flag_object_attributes = flag_object['attributes']
        expect(flag_object_attributes).to include('ip_address', 'representative_id', 'flag_type',
                                                  'flagged_value')
        expect(flag_object_attributes['representative_id']).to eq('1')
        expect(flag_object_attributes['flag_type']).to eq('email')
        expect(flag_object_attributes['flagged_value']).to eq('example@email.com')
      end
    end

    context 'when submitting multiple valid flags' do
      let(:multiple_valid_flags_params) do
        {
          representative_id: '1',
          flags: [
            { flag_type: 'email', flagged_value: 'example1@email.com' },
            { flag_type: 'phone_number', flagged_value: '1234567890' }
          ]
        }
      end

      it 'successfully creates multiple FlaggedVeteranRepresentativeContactData records' do
        expect { post base_path, params: multiple_valid_flags_params }
          .to change(RepresentationManagement::FlaggedVeteranRepresentativeContactData, :count).by(2)
      end

      it 'responds with a created status for multiple flags' do
        post base_path, params: multiple_valid_flags_params
        expect(response).to have_http_status(:created)
      end

      it 'returns the correct serialized data for multiple flags' do
        post base_path, params: multiple_valid_flags_params
        json_response_data = JSON.parse(response.body)['data']

        expect(json_response_data).to be_an(Array)
        expect(json_response_data.length).to eq(2)
        expect(json_response_data[0]['attributes']['flag_type']).to eq('email')
        expect(json_response_data[1]['attributes']['flag_type']).to eq('phone_number')
      end
    end

    context 'when submitting invalid flags' do
      let(:invalid_flags_params) do
        {
          representative_id: nil,
          flags: [{ flag_type: 'invalid_type', flagged_value: 'example@email.com' }]
        }
      end

      it 'does not create any FlaggedVeteranRepresentativeContactData records' do
        expect { post base_path, params: invalid_flags_params }
          .not_to change(RepresentationManagement::FlaggedVeteranRepresentativeContactData, :count)
      end

      it 'responds with an unprocessable entity status' do
        post base_path, params: invalid_flags_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns appropriate error messages' do
        post base_path, params: invalid_flags_params
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('errors')
        expect(json_response['errors']['flag_type']).to be_an(Array)
        expect(json_response['errors']['flag_type'].first).to include('is not a valid flag_type')
      end
    end

    context 'when submitting a mix of valid and invalid flags' do
      let(:mixed_valid_and_invalid_flags_params) do
        {
          representative_id: '1',
          flags: [
            { flag_type: 'email', flagged_value: 'valid@email.com' },
            { flag_type: 'invalid_type', flagged_value: 'invalid@example.com' }
          ]
        }
      end

      it 'does not create any FlaggedVeteranRepresentativeContactData records' do
        expect { post base_path, params: mixed_valid_and_invalid_flags_params }
          .not_to change(RepresentationManagement::FlaggedVeteranRepresentativeContactData, :count)
      end

      it 'responds with an unprocessable entity status' do
        post base_path, params: mixed_valid_and_invalid_flags_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns appropriate error messages for mixed valid and invalid flags' do
        post base_path, params: mixed_valid_and_invalid_flags_params
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('errors')
        expect(json_response['errors']['flag_type']).to be_an(Array)
        expect(json_response['errors']['flag_type'].first).to include('is not a valid flag_type')
      end
    end
  end
end
