# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FlagAccreditedRepresentativesController', type: :request do
  describe 'POST #create' do
    let(:path) { '/services/veteran/v0/flag_accredited_representatives' }

    let(:valid_attributes) do
      {
        ip_address: '192.168.1.1',
        representative_id: '1',
        flag_type: 'email',
        flagged_value: 'example@email.com'
      }
    end

    let(:invalid_attributes) do
      {
        ip_address: nil,
        representative_id: nil,
        flag_type: 'invalid_type',
        flagged_value: 'example@email.com'
      }
    end

    context 'with valid parameters' do
      it 'creates a new FlaggedVeteranRepresentativeContactData' do
        expect do
          post path, params: { flag: valid_attributes }
        end.to change(Veteran::FlaggedVeteranRepresentativeContactData, :count).by(1)
      end

      it 'returns a created status' do
        post path, params: { flag: valid_attributes }
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new FlaggedVeteranRepresentativeContactData' do
        expect do
          post path, params: { flag: invalid_attributes }
        end.not_to change(Veteran::FlaggedVeteranRepresentativeContactData, :count)
      end

      it 'returns an unprocessable entity status' do
        post path, params: { flag: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
