# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Email', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '123498767V234859') }

  before do
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.000Z'))
  end

  after do
    Timecop.return
  end

  describe 'POST /mobile/v0/user/emails' do
    let(:email) { build(:email, email_address: 'person42@example.com') }

    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/post_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/post_email_success', VCR::MATCH_EVERYTHING) do
              puts email.to_json
              post '/mobile/v0/user/emails', params: email.to_json, headers: sis_headers(json: true)
            end
          end
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes a transaction id' do
        id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
        expect(id).to eq('c7c2bfcf-006d-48d4-be8d-a54e57f64536')
      end
    end

    context 'with email missing from params' do
      before do
        put('/mobile/v0/user/emails', params: { email_address: '' }.to_json,
                                      headers: sis_headers(json: true))
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the error schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'has a helpful error message' do
        message = response.parsed_body['errors'].first
        expect(message).to eq(
          {
            'title' => "Email address can't be blank",
            'detail' => "email-address - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/email-address'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'PUT /mobile/v0/user/emails' do
    let(:email) do
      build(:email, id: 318_927, email_address: 'person43@example.com',
                    source_system_user: user.icn)
    end

    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/put_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/put_email_success', VCR::MATCH_EVERYTHING) do
              put '/mobile/v0/user/emails', params: email.to_json, headers: sis_headers(json: true)
            end
          end
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes a transaction id' do
        id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
        expect(id).to eq('c3c712ea-0cfb-484b-b81e-22f11ee0dcaf')
      end
    end

    context 'with email missing from params' do
      before do
        put('/mobile/v0/user/emails', params: { email_address: '' }.to_json,
                                      headers: sis_headers(json: true))
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the error schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'has a helpful error message' do
        message = response.parsed_body['errors'].first
        expect(message).to eq(
          {
            'title' => "Email address can't be blank",
            'detail' => "email-address - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/email-address'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'DELETE /mobile/v0/user/emails' do
    context 'with a valid email' do
      let(:email) do
        build(:email, email_address: 'person42@example.com')
      end

      before do
        Timecop.freeze(Time.zone.local(2018, 6, 6, 15, 35, 55))
        VCR.use_cassette('va_profile/v2/contact_information/delete_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/delete_email_status_incomplete',
                           VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/delete_email_success', VCR::MATCH_EVERYTHING) do
              delete '/mobile/v0/user/emails', params: email.to_json, headers: sis_headers(json: true)
            end
          end
        end
      end

      after do
        Timecop.return
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes a transaction id' do
        id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
        expect(id).to eq('ea7989c5-60ef-40dc-aa6d-2fe6f7b1f0f9')
      end
    end

    context 'with email missing from params' do
      before do
        delete '/mobile/v0/user/emails',
               params: { id: 42, email_address: '' }.to_json,
               headers: sis_headers(json: true)
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the error schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'has a helpful error message' do
        message = response.parsed_body['errors'].first
        expect(message).to eq(
          {
            'title' => "Email address can't be blank",
            'detail' => "email-address - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/email-address'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'parameter handling' do
    let(:all_params) do
      {
        email_address: 'test@example.com',
        confirmation_date: '2023-01-01T00:00:00.000Z',
        id: 123,
        transaction_id: 'b2fab2b5-6af0-45e1-a9e2-394347af9123',
        effective_start_date: '2023-01-01T00:00:00.000Z',
        source_date: '2023-01-01T00:00:00.000Z',
        vet360_id: 456,
        unauthorized_param: 'should_be_filtered'
      }
    end

    it 'permits only allowed parameters' do
      expect_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
        .to receive(:save_and_await_response)
        .with(
          resource_type: :email,
          params: hash_excluding(:unauthorized_param)
        )

      VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
        post '/mobile/v0/user/emails', params: all_params.to_json, headers: sis_headers(json: true)
      end
    end

    it 'includes all permitted parameters' do
      expect_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
        .to receive(:save_and_await_response)
        .with(
          resource_type: :email,
          params: hash_including(
            :email_address,
            :confirmation_date,
            :id,
            :transaction_id,
            :effective_start_date,
            :source_date,
            :vet360_id
          )
        )

      VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
        post '/mobile/v0/user/emails', params: all_params.to_json, headers: sis_headers(json: true)
      end
    end
  end
end
