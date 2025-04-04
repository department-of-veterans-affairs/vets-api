# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS V2 Referrals', type: :request do
  describe 'GET /vaos/v2/referrals' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:icn) { '1012845331V153043' }
    let(:user) { build(:user, :vaos, :loa3, icn:) }
    let(:referrals) { build_list(:ccra_referral_list_entry, 3) }
    let(:service_double) { instance_double(Ccra::ReferralService) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(Ccra::ReferralService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:get_vaos_referral_list).and_return(referrals)
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(user)
      end

      it 'returns referrals list in JSON:API format' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('data')
        expect(response_data['data']).to be_an(Array)
        expect(response_data['data'].length).to eq(3)

        first_referral = response_data['data'].first
        expect(first_referral).to have_key('id')
        expect(first_referral).to have_key('type')
        expect(first_referral).to have_key('attributes')
        expect(first_referral['attributes']).to have_key('type_of_care')
      end
    end
  end

  describe 'GET /vaos/v2/referrals/:id' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:icn) { '1012845331V153043' }
    let(:referral_id) { '5682' }
    let(:user) { build(:user, :vaos, :loa3, icn:) }
    let(:referral) { build(:ccra_referral_detail, referral_number: referral_id) }
    let(:service_double) { instance_double(Ccra::ReferralService) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(Ccra::ReferralService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:get_referral).and_return(referral)
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/vaos/v2/referrals/#{referral_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(user)
      end

      it 'returns referral detail in JSON:API format' do
        get "/vaos/v2/referrals/#{referral_id}"

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('data')
        expect(response_data['data']).to have_key('id')
        expect(response_data['data']['id']).to eq(referral_id)
        expect(response_data['data']).to have_key('type')
        expect(response_data['data']['type']).to eq('referral')
        expect(response_data['data']).to have_key('attributes')
        expect(response_data['data']['attributes']).to have_key('type_of_care')
        expect(response_data['data']['attributes']).to have_key('provider_name')
        expect(response_data['data']['attributes']).to have_key('location')
      end
    end

    context 'when using invalid referral id' do
      let(:invalid_id) { 'invalid' }

      before do
        sign_in_as(user)
        allow(service_double).to receive(:get_referral)
          .with(invalid_id, anything)
          .and_raise(Common::Exceptions::ParameterMissing.new('id'))
      end

      it 'returns appropriate error status' do
        get "/vaos/v2/referrals/#{invalid_id}"

        # Expecting bad request based on how the controller likely handles missing parameters
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
