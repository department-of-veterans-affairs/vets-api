# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require 'va_profile/demographics/service'

RSpec.describe 'preferred_name', type: :request do
  include SchemaMatchers

  describe 'logingov user' do
    let(:login_uri) { 'LGN' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user, :logingov))
      allow_any_instance_of(User).to receive(:logingov_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when text is valid' do
        it 'returns 204', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { login_uri: }) do
            VCR.use_cassette('mobile/demographics/logingov') do
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

              expect(response).to have_http_status(:no_content)
            end
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

  describe 'idme user' do
    let(:login_uri) { 'IDM' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user))
      allow_any_instance_of(User).to receive(:idme_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when text is valid' do
        it 'returns 204', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          VCR.use_cassette('mobile/va_profile/post_preferred_name_success', erb: { login_uri: }) do
            VCR.use_cassette('va_profile/demographics/demographics') do
              put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

              expect(response).to have_http_status(:no_content)
            end
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

  describe 'unauthorized user' do
    before do
      iam_sign_in(FactoryBot.build(:iam_user))
    end

    describe 'PUT /mobile/v0/profile/preferred_names' do
      context 'when text is valid' do
        it 'returns 402', :aggregate_failures do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')
          put('/mobile/v0/user/preferred_name', params: preferred_name.to_h, headers: iam_headers)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
