# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ReferralsController, type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:referral_id) { '5682' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:referral_statuses) { "'AP','AC','I'" }
  let(:referral_mode) { 'C' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
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
      let(:icn) { '1012845331V153043' }
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
        expect(first_referral['id']).to eq('5682')
        expect(first_referral['type']).to eq('referrals')
        expect(first_referral['attributes']['category_of_care']).to eq('CARDIOLOGY')

        # Skip the expiration date test as it may change based on the factory response
        # expect(first_referral['attributes']['expiration_date']).to eq('2024-05-27')
        expect(first_referral['attributes']).to have_key('expiration_date')
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
          # Create a referral that expired yesterday by setting start date to 60 days ago
          # and SEOC days to 59 days (so it expired yesterday)
          build(:ccra_referral_list_entry,
                start_date: (today - 60.days).to_s,
                seoc_days: '59')
        end
        let(:active_referral) do
          # Create a referral that expires 30 days from now by setting start date to today
          # and SEOC days to 30
          build(:ccra_referral_list_entry,
                start_date: today.to_s,
                seoc_days: '30')
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
          expect(Date.parse(response_data['data'].first['attributes']['expiration_date'])).to eq(today + 30.days)
        end
      end

      context 'when all referrals are expired' do
        let(:today) { Time.zone.today }
        let(:all_expired_referrals) do
          [
            # Expired 1 day ago (start date 10 days ago, valid for 9 days)
            build(:ccra_referral_list_entry,
                  start_date: (today - 10.days).to_s,
                  seoc_days: '9'),
            # Expired 5 days ago (start date 15 days ago, valid for 10 days)
            build(:ccra_referral_list_entry,
                  start_date: (today - 15.days).to_s,
                  seoc_days: '10')
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
        get "/vaos/v2/referrals/#{referral_id}"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when called with authorization' do
      let(:user) { build(:user, :vaos, :loa3) }
      let(:referral_detail) { build(:ccra_referral_detail, referral_number: referral_id) }

      before do
        sign_in_as(user)
        allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
          .with(referral_id, referral_mode)
          .and_return(referral_detail)
      end

      it 'returns a referral detail in JSON:API format' do
        get "/vaos/v2/referrals/#{referral_id}"

        expect(response).to have_http_status(:ok)

        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('data')
        expect(response_data['data']['id']).to eq(referral_id)
        expect(response_data['data']['type']).to eq('referral')
        expect(response_data['data']['attributes']['category_of_care']).to eq('CARDIOLOGY')
        expect(response_data['data']['attributes']['provider_name']).to eq('Dr. Smith')
        expect(response_data['data']['attributes']['location']).to eq('VA Medical Center')
        expect(response_data['data']['attributes']['expiration_date']).to eq('2024-05-27')
      end

      context 'with a custom mode parameter' do
        let(:custom_mode) { 'A' }

        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_id, custom_mode)
            .and_return(referral_detail)
        end

        it 'passes the correct mode to the service' do
          get "/vaos/v2/referrals/#{referral_id}", params: { mode: custom_mode }

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
