# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Email', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  before do
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.012Z'))
  end

  after do
    Timecop.return
  end

  describe 'POST /mobile/v0/user/emails' do
    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('mobile/profile/v2/get_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/post_email_initial', VCR::MATCH_EVERYTHING) do
              post '/mobile/v0/user/emails',
                   params: { id: 42, email_address: 'person42@example.com' }.to_json,
                   headers: sis_headers(json: true)
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
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
    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('mobile/profile/v2/get_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/put_email_initial', VCR::MATCH_EVERYTHING) do
              put '/mobile/v0/user/emails',
                  params: { id: 42, email_address: 'person42@example.com' }.to_json,
                  headers: sis_headers(json: true)
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
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
        build(:email, vet360_id: user.vet360_id, email_address: 'person103@example.com')
      end

      let(:id_in_cassette) { 42 }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
        email.id = id_in_cassette

        VCR.use_cassette('mobile/profile/v2/get_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/delete_email_initial', VCR::MATCH_EVERYTHING) do
              delete '/mobile/v0/user/emails',
                     params: { id: 42, email_address: 'person42@example.com' }.to_json,
                     headers: sis_headers(json: true)
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
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
end
