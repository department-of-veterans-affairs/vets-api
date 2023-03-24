# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require 'va_profile/demographics/service'

RSpec.describe 'gender identity', type: :request do
  include SchemaMatchers

  let(:user) { FactoryBot.build(:iam_user) }

  before do
    iam_sign_in(user)
    allow_any_instance_of(VAProfile::Demographics::Service).to receive(:identifier_present?).and_return(true)
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/gender_identity/edit' do
    context 'requested' do
      before do
        get('/mobile/v0/user/gender_identity/edit', headers: iam_headers_no_camel)
      end

      it 'returns a list of valid ids' do
        json = json_body_for(response)['attributes']['options']
        expect(json).to eq(VAProfile::Models::GenderIdentity::OPTIONS)
      end

      it 'returns a list in correct order' do
        codes = response.parsed_body.dig('data', 'attributes', 'options').keys
        expect(codes).to eq(%w[M B TM TF F N O])
      end
    end
  end

  describe 'PUT /mobile/v0/gender_identity' do
    context 'when a valid code is provided' do
      it 'returns a 201' do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

        VCR.use_cassette('va_profile/post_gender_identity_success') do
          put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context 'matches the errors schema' do
      it 'when code is blank', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: nil)

        put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "code - can't be blank"
      end

      it 'when code is an invalid option', :aggregate_failures do
        gender_identity = VAProfile::Models::GenderIdentity.new(code: 'A')

        put('/mobile/v0/user/gender_identity', params: gender_identity.to_h, headers: iam_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'code - invalid code'
      end
    end
  end
end
