# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Phones', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  let(:headers) do
    sis_headers(json: true)
  end
  let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mobile_v2_contact_info, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:va_v3_contact_information_service, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.012Z'))
  end

  after do
    Timecop.return
  end

  describe 'POST /mobile/v0/user/phones', :skip_va_profile_user do
    context 'with a valid phone number' do
      before do
        telephone.id = 42

        VCR.use_cassette('mobile/profile/v2/get_phone_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_phone_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/get_phone_status_incomplete_2', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('mobile/profile/v2/post_phone_initial', VCR::MATCH_EVERYTHING) do
                post('/mobile/v0/user/phones', params: telephone.to_json, headers:)
              end
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with missing params' do
      before do
        telephone.phone_number = ''
        post('/mobile/v0/user/phones', params: telephone.to_json, headers:)
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'PUT /mobile/v0/user/phones' do
    context 'with a valid phone number' do
      before do
        telephone.id = 42

        VCR.use_cassette('mobile/profile/v2/get_phone_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_phone_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/put_phone_initial', VCR::MATCH_EVERYTHING) do
              put('/mobile/v0/user/phones', params: telephone.to_json, headers:)
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with missing params' do
      before do
        telephone.phone_number = ''
        put('/mobile/v0/user/phones', params: telephone.to_json, headers:)
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'DELETE /mobile/v0/user/phones v2' do
    context 'with a valid phone number' do
      before do
        telephone.id = 42
        VCR.use_cassette('mobile/profile/v2/get_phone_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('mobile/profile/v2/get_phone_status_incomplete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('mobile/profile/v2/delete_phone_initial', VCR::MATCH_EVERYTHING) do
              delete '/mobile/v0/user/phones',
                     params: telephone.to_json,
                     headers:
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with missing params' do
      before do
        telephone.phone_number = ''
        post('/mobile/v0/user/phones', params: telephone.to_json, headers:)
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end
end
