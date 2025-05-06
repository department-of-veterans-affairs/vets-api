# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Profile::Persons', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }

  describe 'POST /v0/profile/initialize_vet360_id' do
    before do
      Timecop.freeze('2018-04-09T17:52:03Z')
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
      allow_any_instance_of(User).to receive(:vet360_id).and_return(nil)
    end

    after { Timecop.return }

    let(:empty_body) do
      {
        bio: {
          sourceDate: Time.zone.now.iso8601
        }
      }.to_json
    end

    context 'with a user that has an icn_with_aaid' do
      it 'matches the transaction response schema', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'matches the transaction response camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          post('/v0/profile/initialize_vet360_id', params: empty_body, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::VAProfile::InitializePersonTransaction', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          expect do
            post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)
          end.to change(AsyncTransaction::VAProfile::InitializePersonTransaction, :count).from(0).to(1)

          expect(AsyncTransaction::VAProfile::InitializePersonTransaction.first).to be_valid
        end
      end

      it 'invalidates the cache for the mpi-profile-response Redis key' do
        VCR.use_cassette('va_profile/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
          expect_any_instance_of(User).to receive(:invalidate_mpi_cache)

          post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)
        end
      end
    end

    context 'with an error response' do
      it 'matches the errors response schema', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
          post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors response camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('va_profile/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
          post('/v0/profile/initialize_vet360_id', params: empty_body, headers: headers_with_camel)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end
  end

  describe 'GET /v0/profile/person/status/:transaction_id' do
    before do
      Timecop.freeze('2018-04-09T17:52:03Z')
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
    end

    context 'with an ok response' do
      let(:transaction) do
        create(:initialize_person_transaction,
               :init_vet360_id,
               user_uuid: user.uuid,
               transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4d')
      end

      it 'responds with a serialized transaction', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/person_transaction_status') do
          get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers:)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'responds with a serialized transaction when camel-inflected', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/person_transaction_status') do
          get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end
    end

    context 'with an error response' do
      let(:transaction) do
        create(:initialize_person_transaction,
               :init_vet360_id,
               user_uuid: user.uuid,
               transaction_id: 'd47b3d96-9ddd-42be-ac57-8e564aa38029')
      end

      it 'matches the errors response schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/person_transaction_status_error', VCR::MATCH_EVERYTHING) do
          get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers:)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors response camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/person_transaction_status_error', VCR::MATCH_EVERYTHING) do
          get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers: headers_with_camel)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end
  end

  describe 'contact information v2' do
    before do
      Timecop.freeze('2024-09-16T16:09:37Z')
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    end

    describe 'POST /v0/profile/initialize_vet360_id v2' do
      let(:empty_body) do
        {
          bio: {
            sourceDate: Time.zone.now.iso8601
          }
        }.to_json
      end

      context 'with a user that has an icn' do
        it 'matches the transaction response schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
            post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('va_profile/transaction_response')
          end
        end

        it 'matches the transaction response camel-inflected schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
            post('/v0/profile/initialize_vet360_id', params: empty_body, headers: headers_with_camel)

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('va_profile/transaction_response')
          end
        end

        it 'creates a new AsyncTransaction::VAProfile::InitializePersonTransaction', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
            expect do
              post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)
            end.to change(AsyncTransaction::VAProfile::InitializePersonTransaction, :count).from(0).to(1)

            expect(AsyncTransaction::VAProfile::InitializePersonTransaction.first).to be_valid
          end
        end

        it 'invalidates the cache for the mpi-profile-response Redis key' do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success', VCR::MATCH_EVERYTHING) do
            expect_any_instance_of(User).to receive(:invalidate_mpi_cache)

            post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)
          end
        end
      end

      context 'with an error response' do
        it 'matches the errors response schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
            post('/v0/profile/initialize_vet360_id', params: empty_body, headers:)

            expect(response).to have_http_status(:bad_request)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors response camel-inflected schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_status_400', VCR::MATCH_EVERYTHING) do
            post('/v0/profile/initialize_vet360_id', params: empty_body, headers: headers_with_camel)

            expect(response).to have_http_status(:bad_request)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end
    end

    describe 'GET /v0/profile/person/status/:transaction_id v2' do
      context 'with an ok response' do
        let(:transaction) do
          create(:initialize_person_transaction,
                 :init_vet360_id,
                 user_uuid: user.uuid,
                 transaction_id: '153536a5-8b18-4572-a3d9-4030bea3ab5c')
        end

        it 'responds with a serialized transaction', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status') do
            get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers:)

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('va_profile/transaction_response')
          end
        end

        it 'responds with a serialized transaction when camel-inflected', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status') do
            get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers: headers_with_camel)

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('va_profile/transaction_response')
          end
        end
      end

      context 'with an error response' do
        let(:transaction) do
          create(:initialize_person_transaction,
                 :init_vet360_id,
                 user_uuid: user.uuid,
                 transaction_id: 'd47b3d96-9ddd-42be-ac57-8e564aa38029')
        end

        it 'matches the errors response schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status_error',
                           VCR::MATCH_EVERYTHING) do
            get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers:)

            expect(response).to have_http_status(:bad_request)
            expect(response).to match_response_schema('errors')
          end
        end

        it 'matches the errors response camel-inflected schema', :aggregate_failures do
          VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status_error',
                           VCR::MATCH_EVERYTHING) do
            get("/v0/profile/person/status/#{transaction.transaction_id}", params: nil, headers: headers_with_camel)

            expect(response).to have_http_status(:bad_request)
            expect(response).to match_camelized_response_schema('errors')
          end
        end
      end
    end
  end
end
