# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'user', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/user' do
    before { iam_sign_in }

    context 'with no upstream errors' do
      before { get '/mobile/v0/user', headers: iam_headers }

      let(:attributes) { response.parsed_body.dig('data', 'attributes') }

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a user profile response with the expected schema' do
        expect(response.body).to match_json_schema('user')
      end

      it 'includes the users names' do
        expect(attributes['profile']).to include(
          'firstName' => 'GREG',
          'middleName' => 'A',
          'lastName' => 'ANDERSON'
        )
      end

      it 'includes the users email' do
        expect(attributes['profile']).to include(
          'email' => 'va.api.user+idme.008@gmail.com'
        )
      end

      it 'includes the users birth date' do
        expect(attributes['profile']).to include(
          'birthDate' => '1970-08-12'
        )
      end

      it 'includes the expected residential address' do
        expect(attributes['profile']).to include(
          'residentialAddress' => {
            'addressLine1' => '140 Rock Creek Rd',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => 'RESIDENCE/CHOICE',
            'addressType' => 'DOMESTIC',
            'city' => 'Washington',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'DC',
            'zipCode' => '20011',
            'zipCodeSuffix' => nil
          }
        )
      end

      it 'includes the expected mailing address' do
        expect(attributes['profile']).to include(
          'mailingAddress' => {
            'addressLine1' => '140 Rock Creek Rd',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => 'CORRESPONDENCE',
            'addressType' => 'DOMESTIC',
            'city' => 'Washington',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'DC',
            'zipCode' => '20011',
            'zipCodeSuffix' => nil
          }
        )
      end

      it 'includes a home phone number' do
        expect(attributes['profile']['homePhoneNumber']).to include(
          {
            'id' => 789,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'HOME'
          }
        )
      end

      it 'includes a mobile phone number' do
        expect(attributes['profile']['mobilePhoneNumber']).to include(
          {
            'id' => 791,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'WORK'
          }
        )
      end

      it 'includes a work phone number' do
        expect(attributes['profile']['workPhoneNumber']).to include(
          {
            'id' => 790,
            'areaCode' => '303',
            'countryCode' => '1',
            'extension' => nil,
            'phoneNumber' => '5551234',
            'phoneType' => 'MOBILE'
          }
        )
      end

      it 'includes the service the user has access to' do
        expect(attributes['authorizedServices']).to eq(
          %w[
            appeals
            appointments
            claims
            directDepositBenefits
            lettersAndDocuments
            militaryServiceHistory
            userProfileUpdate
          ]
        )
      end

      it 'includes a complete list of mobile api services (even if the user does not have access to them)' do
        expect(JSON.parse(response.body).dig('meta', 'availableServices')).to eq(
          %w[
            appeals
            appointments
            claims
            directDepositBenefits
            lettersAndDocuments
            militaryServiceHistory
            userProfileUpdate
          ]
        )
      end

      context 'when user object birth_date is nil' do
        before do
          allow_any_instance_of(IAMUserIdentity).to receive(:birth_date).and_return(nil)
          get '/mobile/v0/user', headers: iam_headers
        end

        it 'returns a nil birthdate' do
          expect(response).to have_http_status(:ok)
          expect(attributes['profile']).to include(
            'birthDate' => nil
          )
        end
      end

      context 'with a user who does not have access to evss' do
        before do
          iam_sign_in(FactoryBot.build(:iam_user, :no_edipi_id))
          get '/mobile/v0/user', headers: iam_headers
        end

        it 'does not include edipi services (claims, direct deposit, letters, military history)' do
          expect(attributes['authorizedServices']).to eq(
            %w[
              appeals
              appointments
              userProfileUpdate
            ]
          )
        end
      end
    end

    context 'when the upstream va profile service returns an error' do
      before do
        allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_raise(
          Common::Exceptions::BackendServiceException.new('VET360_502')
        )
      end

      it 'returns a service unavailable error' do
        get '/mobile/v0/user', headers: iam_headers

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'when the va profile service throws an error' do
      before do
        allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_raise(
          ArgumentError.new
        )
      end

      it 'returns an internal service error' do
        get '/mobile/v0/user', headers: iam_headers

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to match_json_schema('errors')
      end
    end
  end

  describe 'GET /mobile/v0/user/logout' do
    before { iam_sign_in }

    context 'with a 200 response' do
      before do
        VCR.use_cassette('iam_ssoe_oauth/revoke_200') do
          get '/mobile/v0/user/logout', headers: iam_headers
        end
      end

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a 400 response' do
      before do
        VCR.use_cassette('iam_ssoe_oauth/revoke_400') do
          get '/mobile/v0/user/logout', headers: iam_headers
        end
      end

      it 'returns a bad_request (400) response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'the response body matches the errors schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'includes the error details' do
        expect(response.parsed_body['errors'].first['detail']).to eq(
          {

            'errorDescription' => 'FBTOAU202E The required parameter: [token] was not found in the request.',
            'error' => 'invalid_request'
          }
        )
      end
    end

    context 'with a 500 response' do
      before do
        VCR.use_cassette('iam_ssoe_oauth/revoke_500') do
          get '/mobile/v0/user/logout', headers: iam_headers
        end
      end

      it 'returns a bad_gateway (502) response' do
        expect(response).to have_http_status(:bad_gateway)
      end

      it 'the response body matches the errors schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'includes generic error details to avoid leaking data' do
        expect(response.parsed_body['errors'].first['detail']).to eq(
          'Received an an invalid response from the upstream server'
        )
      end
    end
  end
end
