# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Phones', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  let(:headers) do
    sis_headers(json: true)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.012Z'))
  end

  after do
    Timecop.return
  end

  describe 'POST /mobile/v0/user/phones' do
    let(:telephone) { build(:telephone, :contact_info_v2, id: nil, source_system_user: user.icn) }

    context 'with a valid phone number' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/post_phone_status_complete') do
          VCR.use_cassette('va_profile/v2/contact_information/post_phone_status_incomplete') do
            VCR.use_cassette('va_profile/v2/contact_information/post_telephone_success') do
              post('/mobile/v0/user/phones', params: telephone.to_json, headers:)
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
        expect(id).to eq('57d5364b-149a-4802-bc18-b9b0b0742db6')
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
    let(:telephone) do
      build(:telephone, :contact_info_v2, source_system_user: user.icn, id: 458_781, phone_number: 5_551_235)
    end

    context 'with a valid phone number' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/put_telephone_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/put_telephone_status_incomplete',
                           VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/put_telephone_success', VCR::MATCH_EVERYTHING) do
              put('/mobile/v0/user/phones', params: telephone.to_json, headers: sis_headers(json: true))
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
        expect(id).to eq('c915d801-5693-4860-b2df-83baa8c3c910')
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
    let(:telephone) { build(:telephone, :contact_info_v2, source_system_user: user.icn, id: 42) }

    context 'with a valid phone number' do
      before do
        VCR.use_cassette('va_profile/v2/contact_information/delete_telephone_status_complete', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/v2/contact_information/delete_telephone_status_incomplete',
                           VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/delete_telephone_success', VCR::MATCH_EVERYTHING) do
              delete '/mobile/v0/user/phones', params: telephone.to_json, headers:
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
        expect(id).to eq('2c5b8109-e709-463c-a7c4-19dadfbbc2ed')
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
