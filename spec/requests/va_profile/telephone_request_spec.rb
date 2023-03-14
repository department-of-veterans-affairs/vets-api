# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'telephone' do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }
  let(:time) { Time.zone.local(2018, 6, 6, 15, 35, 55) }

  before do
    Timecop.freeze(time)
    sign_in_as(user)
  end

  after do
    Timecop.return
  end

  describe 'POST /v0/profile/telephones/create_or_update' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    it 'calls update_telephone' do
      expect_any_instance_of(VAProfile::ContactInformation::Service).to receive(:update_telephone).and_call_original
      VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
        post('/v0/profile/telephones/create_or_update', params: telephone.to_json, headers: headers)
      end

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /v0/profile/telephones' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'matches the telephone schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/post_telephone_success') do
          post('/v0/profile/telephones', params: telephone.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'matches the telephone camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/post_telephone_success') do
          post('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::VAProfile::TelephoneTransaction db record' do
        VCR.use_cassette('va_profile/contact_information/post_telephone_success') do
          expect do
            post('/v0/profile/telephones', params: telephone.to_json, headers: headers)
          end.to change(AsyncTransaction::VAProfile::TelephoneTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a 400 response' do
      it 'matches the errors schema', :aggregate_failures do
        telephone.id = 42

        VCR.use_cassette('va_profile/contact_information/post_telephone_w_id_error') do
          post('/v0/profile/telephones', params: telephone.to_json, headers: headers)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        telephone.id = 42

        VCR.use_cassette('va_profile/contact_information/post_telephone_w_id_error') do
          post('/v0/profile/telephones', params: telephone.to_json, headers: headers)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('va_profile/contact_information/post_telephone_status_403') do
          post('/v0/profile/telephones', params: telephone.to_json, headers: headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a validation issue' do
      it 'matches the errors schema', :aggregate_failures do
        telephone.phone_number = ''

        post('/v0/profile/telephones', params: telephone.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        telephone.phone_number = ''

        post('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end
    end
  end

  describe 'PUT /v0/profile/telephones' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    before { telephone.id = 42 }

    context 'with a 200 response' do
      it 'matches the telephone schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          put('/v0/profile/telephones', params: telephone.to_json, headers: headers)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'matches the telephone camel-inflected schema', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          put('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::VAProfile::TelephoneTransaction db record' do
        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          expect do
            put('/v0/profile/telephones', params: telephone.to_json, headers: headers)
          end.to change(AsyncTransaction::VAProfile::TelephoneTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a validation issue' do
      it 'matches the errors schema', :aggregate_failures do
        telephone.phone_number = ''

        put('/v0/profile/telephones', params: telephone.to_json, headers: headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        telephone.phone_number = ''

        put('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end
    end

    context 'when effective_end_date is included' do
      let(:time) { Time.zone.parse('2020-01-17T04:21:59.000Z') }
      let(:telephone) do
        build(:telephone,
              vet360_id: user.vet360_id,
              effective_end_date: Time.now.utc.iso8601,
              phone_number: '5551234')
      end
      let(:id_in_cassette) { 17_259 }

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return('1')
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
        telephone.id = id_in_cassette
      end

      it 'effective_end_date is NOT included in the request body', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/put_telephone_ignore_eed', VCR::MATCH_EVERYTHING) do
          # The cassette we're using does not include the effectiveEndDate in the body.
          # So this test ensures that it was stripped out
          put('/v0/profile/telephones', params: telephone.to_json, headers: headers)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'effective_end_date is NOT included in the request body when camel-inflected', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/put_telephone_ignore_eed', VCR::MATCH_EVERYTHING) do
          # The cassette we're using does not include the effectiveEndDate in the body.
          # So this test ensures that it was stripped out
          put('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end
    end
  end

  describe 'DELETE /v0/profile/telephones' do
    let(:user) { build(:user, :loa3, icn: '64762895576664260') }
    let(:telephone) do
      build(:telephone, vet360_id: user.vet360_id)
    end
    let(:id_in_cassette) { 42 }

    before do
      telephone.id = id_in_cassette
    end

    context 'when the method is DELETE' do
      it 'effective_end_date gets appended to the request body', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/delete_telephone_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete('/v0/profile/telephones', params: telephone.to_json, headers: headers)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end

      it 'effective_end_date gets appended to the request body when camel-inflected', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/delete_telephone_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete('/v0/profile/telephones', params: telephone.to_json, headers: headers_with_camel)
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('va_profile/transaction_response')
        end
      end
    end
  end
end
