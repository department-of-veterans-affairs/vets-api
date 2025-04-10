# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ReferralsController do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:referral_number) { '5682' }
  let(:encrypted_uuid) { 'encrypted-5682' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:referral_statuses) { "'AP','AC','I'" }
  let(:referral_mode) { 'C' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    allow(VAOS::ReferralEncryptionService).to receive(:encrypt).with(referral_number).and_return(encrypted_uuid)
    allow(VAOS::ReferralEncryptionService).to receive(:decrypt).with(encrypted_uuid).and_return(referral_number)
  end

  context 'request specs', type: :request do
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
          expect(first_referral['id']).to eq('encrypted-5682')
          expect(first_referral['type']).to eq('referrals')
          expect(first_referral['attributes']['categoryOfCare']).to eq('CARDIOLOGY')
          expect(first_referral['attributes']['referralNumber']).to eq('5682')

          # Verify expiration date is present and in the future
          expect(first_referral['attributes']).to have_key('expirationDate')
          parsed_date = Date.parse(first_referral['attributes']['expirationDate'])
          expect(parsed_date).to be >= Date.current
        end

        context 'with expired referrals' do
          let(:future_referral) { build(:ccra_referral_list_entry, referral_number: '1001') }
          let(:expired_referral) do
            build(:ccra_referral_list_entry, referral_number: '1002', start_date: '2023-01-01', seoc_days: '30')
          end
          let(:today_referral) { build(:ccra_referral_list_entry, referral_number: '1003') }
          let(:no_expiration_referral) { build(:ccra_referral_list_entry, referral_number: '1004', seoc_days: nil) }
          let(:mixed_referrals) { [future_referral, expired_referral, today_referral, no_expiration_referral] }

          before do
            # Set specific expiration dates
            future_date = Date.current + 30.days
            allow(future_referral).to receive(:expiration_date).and_return(future_date)

            expired_date = Date.current - 1.day
            allow(expired_referral).to receive(:expiration_date).and_return(expired_date)

            today_date = Date.current
            allow(today_referral).to receive(:expiration_date).and_return(today_date)

            allow(no_expiration_referral).to receive(:expiration_date).and_return(nil)

            # Mock encryption for each referral
            mixed_referrals.each do |ref|
              allow(VAOS::ReferralEncryptionService).to receive(:encrypt)
                .with(ref.referral_number)
                .and_return("encrypted-#{ref.referral_number}")
            end

            allow_any_instance_of(Ccra::ReferralService).to receive(:get_vaos_referral_list)
              .with(icn, referral_statuses)
              .and_return(mixed_referrals)
          end

          it 'filters out expired referrals' do
            get '/vaos/v2/referrals'

            expect(response).to have_http_status(:ok)

            response_data = JSON.parse(response.body)
            expect(response_data).to have_key('data')
            expect(response_data['data']).to be_an(Array)

            # Should only include future, today, and nil expiration referrals (not expired)
            expect(response_data['data'].size).to eq(3)

            referral_numbers = response_data['data'].map { |r| r['attributes']['referralNumber'] }
            expect(referral_numbers).to include('1001', '1003', '1004')
            expect(referral_numbers).not_to include('1002')
          end
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
          get "/vaos/v2/referrals/#{encrypted_uuid}"

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)).to eq(resp)
        end
      end

      context 'when called with authorization' do
        let(:user) { build(:user, :vaos, :loa3) }
        let(:referral_detail) { build(:ccra_referral_detail, referral_number:) }

        before do
          sign_in_as(user)
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_number, referral_mode)
            .and_return(referral_detail)
        end

        it 'returns a referral detail in JSON:API format' do
          get "/vaos/v2/referrals/#{encrypted_uuid}"

          expect(response).to have_http_status(:ok)

          response_data = JSON.parse(response.body)
          expect(response_data).to have_key('data')
          expect(response_data['data']['id']).to eq(encrypted_uuid)
          expect(response_data['data']['type']).to eq('referrals')
          expect(response_data['data']['attributes']['categoryOfCare']).to eq('CARDIOLOGY')
          expect(response_data['data']['attributes']['providerName']).to eq('Dr. Smith')
          expect(response_data['data']['attributes']['location']).to eq('VA Medical Center')

          # Verify expiration date is present and in the future
          expect(response_data['data']['attributes']).to have_key('expirationDate')
          parsed_date = Date.parse(response_data['data']['attributes']['expirationDate'])
          expect(parsed_date).to be >= Date.current

          expect(response_data['data']['attributes']['referralNumber']).to eq(referral_number)
        end

        context 'with a custom mode parameter' do
          let(:custom_mode) { 'A' }

          before do
            allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
              .with(referral_number, custom_mode)
              .and_return(referral_detail)
          end

          it 'passes the correct mode to the service' do
            get "/vaos/v2/referrals/#{encrypted_uuid}", params: { mode: custom_mode }

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end

  # Unit tests for private methods
  context 'controller specs', type: :controller do
    describe '#filter_expired_referrals' do
      let(:controller) { described_class.new }
      let(:future_referral) { instance_double(Ccra::ReferralListEntry, expiration_date: Date.current + 5.days) }
      let(:today_referral) { instance_double(Ccra::ReferralListEntry, expiration_date: Date.current) }
      let(:expired_referral) { instance_double(Ccra::ReferralListEntry, expiration_date: Date.current - 1.day) }
      let(:nil_expiration_referral) { instance_double(Ccra::ReferralListEntry, expiration_date: nil) }

      it 'filters out referrals with expiration dates before today' do
        referrals = [future_referral, today_referral, expired_referral, nil_expiration_referral]

        # Use send to call private method
        result = controller.send(:filter_expired_referrals, referrals)

        # Should include future, today, and nil expiration referrals
        expect(result).to include(future_referral, today_referral, nil_expiration_referral)
        expect(result).not_to include(expired_referral)
        expect(result.size).to eq(3)
      end

      it 'returns an empty array when given nil' do
        result = controller.send(:filter_expired_referrals, nil)
        expect(result).to eq([])
      end

      it 'handles empty arrays' do
        result = controller.send(:filter_expired_referrals, [])
        expect(result).to eq([])
      end
    end
  end
end
