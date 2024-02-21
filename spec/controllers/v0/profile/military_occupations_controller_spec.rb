# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::MilitaryOccupationsController, type: :controller do
  let(:user) { create(:user, :loa3, edipi: '1100377582') }

  before do
    sign_in_as(user)
  end

  describe '#show' do
    context 'when feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_enhanced_military_info, instance_of(User))
                                            .and_return(true)
      end

      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/profile/v3/military_occupations_200') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body['status']).to eq(200)
        expect(body['military_occupations'].size).to eq(3)
        expect(body['messages'].size).to eq(0)
      end
    end

    context 'when feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_enhanced_military_info, instance_of(User))
                                            .and_return(false)
      end

      it 'returns a status of 404' do
        VCR.use_cassette('va_profile/profile/v3/military_occupations_200') do
          get(:show)
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user does not have edipi' do
      let(:user) { create(:user, :loa3, edipi: nil) }

      it 'returns a status of 403' do
        VCR.use_cassette('va_profile/profile/v3/military_occupations_200') do
          get(:show)
        end

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
