# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require 'va_profile/demographics/service'

RSpec.describe 'preferred_name', type: :request do
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

  describe 'PUT /mobile/v0/profile/preferred_names' do
    context 'when text is valid' do
      it 'returns 204', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
        VCR.use_cassette('va_profile/post_preferred_name_success') do
          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context 'when text is blank' do
      it 'matches the errors schema', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: nil)

        put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "text - can't be blank"
      end
    end

    context 'when text is too long' do
      it 'matches the errors schema', :aggregate_failures do
        preferred_name = VAProfile::Models::PreferredName.new(text: 'A' * 26)

        put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'text - is too long (maximum is 25 characters)'
      end
    end
  end
end
