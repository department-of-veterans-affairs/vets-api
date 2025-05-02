# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ReferralsController, type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:referral_number) { '5682' }
  let(:referral_consult_id) { '984_646372' }
  let(:encrypted_referral_consult_id) { 'encrypted-984_646372' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:referral_statuses) { "'AP','AC','I'" }
  let(:icn) { '1012845331V153043' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    allow(VAOS::ReferralEncryptionService).to receive(:encrypt).with(referral_consult_id).and_return(encrypted_referral_consult_id)
    allow(VAOS::ReferralEncryptionService).to receive(:decrypt).with(encrypted_referral_consult_id).and_return(referral_consult_id)
  end

  describe 'GET index' do
    context 'when called without authorization' do
      let(:resp) do
        {
          'errors' => [
            {
              'title' => 'Not authorized',
              'detail' => 'Not authorized',
              'code' => '401',
              'status' => '401'
            }
          ]
        }
      end

      it 'throws unauthorized exception' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when called with authorization' do
      let(:user) { build(:user, :vaos, :loa3, icn:) }
      let(:referral_list_entries) { build_list(:ccra_referral_list_entry, 3) }

      before do
        sign_in_as(user)
        allow_any_instance_of(Ccra::ReferralService).to receive(:get_vaos_referral_list)
          .with(icn, referral_statuses)
          .and_return(referral_list_entries)
      end

      it 'returns a list of referrals in JSON:API format' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:ok)

        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('data')
        expect(response_data['data']).to be_an(Array)
        expect(response_data['data'].size).to eq(3)

        # Verify first referral entry structure
        first_referral = response_data['data'].first
        expect(first_referral['id']).to eq(referral_consult_id)
        expect(first_referral['type']).to eq('referrals')
        expect(first_referral['attributes']['categoryOfCare']).to eq('CARDIOLOGY')
        expect(first_referral['attributes']['referralNumber']).to eq('5682')
        expect(first_referral['attributes']['referralConsultId']).to eq(referral_consult_id)
        expect(first_referral['attributes']['expirationDate']).to eq((Date.current + 60.days).strftime('%Y-%m-%d'))
      end

      context 'with a custom status parameter' do
        let(:custom_statuses) { "'A','I'" }

        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_vaos_referral_list)
            .with(icn, custom_statuses)
            .and_return(referral_list_entries)
        end

        it 'passes the correct status to the service' do
          get '/vaos/v2/referrals', params: { status: custom_statuses }

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when filtering expired referrals' do
        let(:today) { Time.zone.today }
        let(:expired_referral) do
          # Create a referral that expired yesterday
          build(:ccra_referral_list_entry,
                referral_expiration_date: (today - 1.day).to_s)
        end
        let(:active_referral) do
          # Create a referral that expires 30 days from now
          build(:ccra_referral_list_entry,
                referral_expiration_date: (today + 30.days).to_s)
        end
        let(:mixed_referrals) { [expired_referral, active_referral] }

        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_vaos_referral_list)
            .with(icn, referral_statuses)
            .and_return(mixed_referrals)
        end

        it 'filters out expired referrals automatically' do
          get '/vaos/v2/referrals'

          expect(response).to have_http_status(:ok)

          response_data = JSON.parse(response.body)
          expect(response_data['data'].size).to eq(1)
          # The active referral should have an expiration date 30 days from today
          expect(Date.parse(response_data['data'].first['attributes']['expirationDate'])).to eq(today + 30.days)
        end
      end

      context 'when all referrals are expired' do
        let(:today) { Time.zone.today }
        let(:all_expired_referrals) do
          [
            # Expired 1 day ago
            build(:ccra_referral_list_entry,
                  referral_expiration_date: (today - 1.day).to_s),
            # Expired 5 days ago
            build(:ccra_referral_list_entry,
                  referral_expiration_date: (today - 5.days).to_s)
          ]
        end

        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_vaos_referral_list)
            .with(icn, referral_statuses)
            .and_return(all_expired_referrals)
        end

        it 'returns an empty data array' do
          get '/vaos/v2/referrals'

          expect(response).to have_http_status(:ok)

          response_data = JSON.parse(response.body)
          expect(response_data['data']).to be_an(Array)
          expect(response_data['data']).to be_empty
        end
      end
    end
  end

  describe 'GET show' do
    context 'when called without authorization' do
      let(:resp) do
        {
          'errors' => [
            {
              'title' => 'Not authorized',
              'detail' => 'Not authorized',
              'code' => '401',
              'status' => '401'
            }
          ]
        }
      end

      it 'throws unauthorized exception' do
        get "/vaos/v2/referrals/#{encrypted_referral_consult_id}"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when called with authorization' do
      let(:user) { build(:user, :vaos, :loa3, icn:) }
      let(:referral_detail) { build(:ccra_referral_detail, referral_consult_id:, referral_number:) }

      before do
        sign_in_as(user)
        allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
          .with(referral_consult_id, icn)
          .and_return(referral_detail)
      end

      it 'returns a referral detail in JSON:API format' do
        get "/vaos/v2/referrals/#{encrypted_referral_consult_id}"

        expect(response).to have_http_status(:ok)

        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('data')
        expect(response_data['data']['id']).to eq(encrypted_referral_consult_id)
        expect(response_data['data']['type']).to eq('referrals')
        expect(response_data['data']['attributes']['categoryOfCare']).to eq('CARDIOLOGY')
        expect(response_data['data']['attributes']['provider']['name']).to eq('Dr. Smith')
        expect(response_data['data']['attributes']['referringFacility']['name']).to be_present
        expect(response_data['data']['attributes']['expirationDate']).to be_a(String)
        expect(response_data['data']['attributes']['referralNumber']).to eq(referral_number)
        expect(response_data['data']['attributes']['referralConsultId']).to eq(referral_consult_id)
      end
    end
  end
end
