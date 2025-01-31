# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BenefitsReferenceDataController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable) }

  before do
    sign_in_as(user)
  end

  describe '#get_data' do
    it 'gets data from lighthouse when valid path end-point is provided' do
      VCR.use_cassette('lighthouse/benefits_reference_data/200_disabilities_response') do
        get(:get_data, params: { path: 'disabilities' })
      end
      expect(response).to have_http_status(:ok)
      returned_data = JSON.parse(response.body)
      expect(returned_data.keys.sort).to eq(%w[items links totalItems totalPages])
      expect(returned_data).is_a?(Hash)
      expect(returned_data['items'].size).to eq(9)
      returned_data['items'].each do |disability|
        expect(disability.keys).to include('id')
        expect(disability['id']).is_a?(Integer)
        expect(disability.keys).to include('name')
        expect(disability['name']).is_a?(String)
        expect(disability.keys).to include('endDateTime')
      end
    end

    it 'gets an error if a non-existing path end-point is specified' do
      VCR.use_cassette('lighthouse/benefits_reference_data/404_response') do
        get(:get_data, params: { path: 'a_non_existing_end_point' })
      end
      expect(response).to have_http_status(:not_found)
      returned_data = JSON.parse(response.body)
      expect(returned_data).to eq(
        {
          errors: [
            {
              title: 'Resource not found',
              detail: 'Resource not found',
              code: '404',
              status: '404'
            }
          ]
        }.deep_stringify_keys
      )
    end
  end
end
