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

      let(:attributes) { JSON.parse(response.body).dig('data', 'attributes') }

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
    end

    context 'when the upstream va profile service returns an error' do
      before do
        allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_raise(
          Common::Exceptions::BackendServiceException.new('VET360_502')
        )
      end

      it 'returns an service unavailable error' do
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

      it 'returns an service unavailable error' do
        get '/mobile/v0/user', headers: iam_headers

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to match_json_schema('errors')
      end
    end
  end
end
