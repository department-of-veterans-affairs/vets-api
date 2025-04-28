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

      # Mock the encryption service for each referral in the list
      referrals.each do |ref|
        allow(VAOS::ReferralEncryptionService).to receive(:encrypt)
          .with(ref.referral_number)
          .and_return("encrypted-#{ref.referral_number}")
      end
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
        expect(first_referral['attributes']).to have_key('categoryOfCare')
        expect(first_referral['attributes']).to have_key('referralNumber')
      end
    end

    context 'when a configuration error occurs' do
      # Note we only test this once as the code is the same for both endpoints
      let(:jwt_error) { Common::JwtWrapper::ConfigurationError.new('Configuration error occurred') }
      let(:config_error) { VAOS::Exceptions::ConfigurationError.new(jwt_error, 'CCRA') }

      before do
        sign_in_as(user)
        allow(service_double).to receive(:get_vaos_referral_list).and_raise(config_error)
      end

      it 'returns 503 Service Unavailable with properly formatted error response' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:service_unavailable)

        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('errors')
        expect(response_data['errors']).to be_an(Array)
        expect(response_data['errors'].first).to include(
          'title' => 'Service Configuration Error',
          'detail' => 'The CCRA service is unavailable due to a configuration issue',
          'code' => 'VAOS_CONFIG_ERROR',
          'status' => '503'
        )
      end

      it 'does not expose internal error details' do
        get '/vaos/v2/referrals'

        response_data = JSON.parse(response.body)

        # Original error message is not leaked
        expect(response_data['errors'].first['detail']).not_to include('Configuration error occurred')

        # No stack trace is included
        expect(response_data['errors'].first).not_to have_key('meta')
        expect(response_data['errors'].first).not_to have_key('backtrace')
      end
    end
  end

  describe 'GET /vaos/v2/referrals/:id' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:icn) { '1012845331V153043' }
    let(:referral_number) { 'VA0000005681' }
    let(:encrypted_uuid) { 'encrypted-VA0000005681' }
    let(:user) { build(:user, :vaos, :loa3, icn:) }
    let(:referral) { build(:ccra_referral_detail, referral_number:) }
    let(:service_double) { instance_double(Ccra::ReferralService) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(Ccra::ReferralService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:get_referral).and_return(referral)
      allow(VAOS::ReferralEncryptionService).to receive(:encrypt).with(referral_number).and_return(encrypted_uuid)
      allow(VAOS::ReferralEncryptionService).to receive(:decrypt).with(encrypted_uuid).and_return(referral_number)
      allow(VAOS::ReferralEncryptionService)
        .to receive(:decrypt)
        .with('invalid')
        .and_raise(Common::Exceptions::ParameterMissing.new('id'))
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/vaos/v2/referrals/#{encrypted_uuid}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(user)
      end

      it 'returns referral detail in JSON:API format' do
        get "/vaos/v2/referrals/#{encrypted_uuid}"

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('data')
        expect(response_data['data']).to have_key('id')
        expect(response_data['data']['id']).to eq(encrypted_uuid)
        expect(response_data['data']).to have_key('type')
        expect(response_data['data']['type']).to eq('referrals')
        expect(response_data['data']).to have_key('attributes')
        expect(response_data['data']['attributes']).to have_key('categoryOfCare')

        # Check nested provider attributes
        expect(response_data['data']['attributes']).to have_key('provider')
        provider = response_data['data']['attributes']['provider']
        expect(provider).to be_a(Hash)
        expect(provider).to have_key('name')
        expect(provider).to have_key('location')

        # Check referring facility attributes - ensure it exists in the response
        expect(response_data['data']['attributes']).to have_key('referringFacility')
        facility = response_data['data']['attributes']['referringFacility']
        expect(facility).to be_a(Hash)
        expect(facility).to have_key('name')
        expect(facility).to have_key('code')
        expect(facility).to have_key('phone')

        expect(response_data['data']['attributes']).to have_key('referralNumber')
      end
    end

    context 'when using invalid referral id' do
      let(:invalid_id) { 'invalid' }

      before do
        sign_in_as(user)
      end

      it 'returns appropriate error status' do
        get "/vaos/v2/referrals/#{invalid_id}"

        # Expecting bad request based on how the controller likely handles missing parameters
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
