# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'address', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }
  let(:frozen_time) { Time.zone.local(2018, 6, 6, 15, 35, 55) }

  before do
    Timecop.freeze(frozen_time)
    sign_in_as(user)
  end

  after do
    Timecop.return
  end

  describe 'POST /v0/profile/addresses' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'matches the address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_success') do
          post('/v0/profile/addresses', params: address.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'matches the address camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_success') do
          post('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::AddressTransaction db record' do
        VCR.use_cassette('vet360/contact_information/post_address_success') do
          expect do
            post('/v0/profile/addresses', params: address.to_json, headers: headers)
          end.to change(AsyncTransaction::Vet360::AddressTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a 400 response' do
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_w_id_error') do
          post('/v0/profile/addresses', params: address.to_json, headers: headers)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_w_id_error') do
          post('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with a low confidence error' do
      it 'returns the low confidence error error code', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_w_low_confidence_error') do
          low_confidence_error = 'VET360_ADDR306'

          post('/v0/profile/addresses', params: address.to_json, headers: headers)

          body = JSON.parse response.body
          expect(body['errors'].first['code']).to eq low_confidence_error
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'returns the low confidence error error code when camel-inflected', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_address_w_low_confidence_error') do
          low_confidence_error = 'VET360_ADDR306'

          post('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

          body = JSON.parse response.body
          expect(body['errors'].first['code']).to eq low_confidence_error
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('vet360/contact_information/post_address_status_403') do
          post('/v0/profile/addresses', params: address.to_json, headers: headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a validation issue' do
      it 'matches the errors schema', :aggregate_failures do
        address.address_pou = ''

        post('/v0/profile/addresses', params: address.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        address.address_pou = ''

        post('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end
    end
  end

  describe 'PUT /v0/profile/addresses' do
    let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'matches the email address schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          put('/v0/profile/addresses', params: address.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'matches the email address camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          put('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::AddressTransaction db record' do
        VCR.use_cassette('vet360/contact_information/put_address_success') do
          expect do
            put('/v0/profile/addresses', params: address.to_json, headers: headers)
          end.to change(AsyncTransaction::Vet360::AddressTransaction, :count).from(0).to(1)
        end
      end

      context 'with a validation key' do
        let(:address) { build(:vet360_address, :override) }
        let(:frozen_time) { Time.zone.parse('2020-02-14T00:19:15.000Z') }

        before do
          allow_any_instance_of(User).to receive(:vet360_id).and_return('1')
          allow_any_instance_of(User).to receive(:icn).and_return('1234')
          Settings.virtual_hosts << 'www.example.com'
        end

        it 'is successful' do
          VCR.use_cassette('vet360/contact_information/put_address_override', VCR::MATCH_EVERYTHING) do
            put('/v0/profile/addresses', params: address.to_json, headers: headers)

            expect(JSON.parse(response.body)['data']['attributes']['transaction_id']).to eq(
              '7f01230f-56e3-4289-97ed-6168d2d23722'
            )
          end
        end
      end
    end

    context 'with a validation issue' do
      it 'matches the errors schema', :aggregate_failures do
        address.address_pou = ''

        put('/v0/profile/addresses', params: address.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        address.address_pou = ''

        put('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include "address-pou - can't be blank"
      end
    end

    context 'when effective_end_date is included' do
      let(:address) do
        build(:vet360_address,
              effective_end_date: Time.now.utc.iso8601)
      end

      it 'effective_end_date is NOT included in the request body', :aggregate_failures do
        expect_any_instance_of(Vet360::ContactInformation::Service).to receive(:put_address) do |_, address|
          expect(address.effective_end_date).to eq(nil)
        end

        put('/v0/profile/addresses', params: address.to_json, headers: headers)
      end
    end
  end

  describe 'DELETE /v0/profile/addresses' do
    context 'when the method is DELETE' do
      let(:frozen_time) { Time.zone.parse('2020-02-13T20:47:45.000Z') }
      let(:address) do
        { 'address_line1' => '4041 Victoria Way',
          'address_line2' => nil,
          'address_line3' => nil,
          'address_pou' => 'CORRESPONDENCE',
          'address_type' => 'DOMESTIC',
          'city' => 'Lexington',
          'country_code_iso3' => 'USA',
          'country_code_fips' => nil,
          'county_code' => '21067',
          'county_name' => 'Fayette County',
          'created_at' => '2019-10-25T17:06:15.000Z',
          'effective_end_date' => nil,
          'effective_start_date' => '2020-02-10T17:40:15.000Z',
          'id' => 138_225,
          'international_postal_code' => nil,
          'province' => nil,
          'source_system_user' => nil,
          'state_code' => 'KY',
          'transaction_id' => '537b388e-344a-474e-be12-08d43cf35d69',
          'updated_at' => '2020-02-10T17:40:25.000Z',
          'validation_key' => nil,
          'vet360_id' => '1',
          'zip_code' => '40515',
          'zip_code_suffix' => '4655' }
      end

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return('1')
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      it 'effective_end_date gets appended to the request body', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete('/v0/profile/addresses', params: address.to_json, headers: headers)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'effective_end_date gets appended to the request body when camel-inflected', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete('/v0/profile/addresses', params: address.to_json, headers: headers_with_camel)
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('vet360/transaction_response')
        end
      end
    end
  end
end
