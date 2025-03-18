# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Email', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.000Z'))
  end

  after do
    Timecop.return
  end

  describe 'POST /mobile/v0/user/emails' do
    let(:email) { build(:email, :contact_info_v2, email_address: 'person42@example.com') }

    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/post_email_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/post_email_success', VCR::MATCH_EVERYTHING) do
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
      build(:email, :contact_info_v2, id: 318_927, email_address: 'person43@example.com',
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
end
