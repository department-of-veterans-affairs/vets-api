# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FlagAccreditedRepresentativesController', csrf: false, type: :request do
  describe 'POST #create' do
    let(:base_path) { '/services/veteran/v0/flag_accredited_representatives' }

    context 'when submitting a single valid flag' do
      let(:single_valid_flag_params) do
        {
          representative_id: '1',
          flags: [{ flag_type: 'email', flagged_value: 'example@email.com' }]
        }
      end

      it 'successfully creates a FlaggedVeteranRepresentativeContactData record' do
        expect { post base_path, params: single_valid_flag_params }
          .to change(Veteran::FlaggedVeteranRepresentativeContactData, :count).by(1)
      end

      it 'responds with a created status' do
        post base_path, params: single_valid_flag_params
        expect(response).to have_http_status(:created)
      end
    end

    context 'when submitting multiple valid flags' do
      let(:multiple_valid_flags_params) do
        {
          representative_id: '1',
          flags: [
            { flag_type: 'email', flagged_value: 'example1@email.com' },
            { flag_type: 'phone', flagged_value: '1234567890' }
          ]
        }
      end

      it 'successfully creates multiple FlaggedVeteranRepresentativeContactData records' do
        expect { post base_path, params: multiple_valid_flags_params }
          .to change(Veteran::FlaggedVeteranRepresentativeContactData, :count).by(2)
      end

      it 'responds with a created status for multiple flags' do
        post base_path, params: multiple_valid_flags_params
        expect(response).to have_http_status(:created)
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
          .not_to change(Veteran::FlaggedVeteranRepresentativeContactData, :count)
      end

      it 'responds with an unprocessable entity status' do
        post base_path, params: invalid_flags_params
        expect(response).to have_http_status(:unprocessable_entity)
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
          .not_to change(Veteran::FlaggedVeteranRepresentativeContactData, :count)
      end

      it 'responds with an unprocessable entity status' do
        post base_path, params: mixed_valid_and_invalid_flags_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
