# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ApplicationController, type: :request do
  describe 'GET /accredited_representative_portal/arbitrary' do
    subject do
      get '/accredited_representative_portal/arbitrary'
      response
    end

    let(:arp_client_id) { 'arp' }
    let(:invalid_client_id) { 'invalid' }

    let(:valid_access_token) { create(:access_token, audience: [arp_client_id]) }
    let(:invalid_access_token) { create(:access_token, audience: [invalid_client_id]) }
    let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: valid_access_token).perform }

    before do
      AccreditedRepresentativePortal::Engine.routes.draw do
        get 'arbitrary', to: 'arbitrary#arbitrary'
      end
    end

    after do
      # We could have set up our test such that we can unset
      # `ArbitraryController` as a const during cleanup. But we'll just leave it
      # around and avoid the extra metaprogramming.
      Rails.application.reload_routes!
    end

    context 'when authenticated' do
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }
      let(:representative_attributes) { {} }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
        create(:representative, representative_attributes)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
      end

      context 'with a valid audience' do
        context 'when the representative is found' do
          let(:session) { SignIn::OAuthSession.find_by(handle: valid_access_token.session_handle) }
          let(:representative_attributes) do
            { first_name: session.user_attributes_hash['first_name'],
              last_name: session.user_attributes_hash['last_name'],
              ssn: mpi_profile.ssn,
              dob: mpi_profile.birth_date }
          end

          it 'allows access' do
            expect(subject).to have_http_status(:ok)
          end

          context 'when the representatives_portal_api feature toggle' do
            before do
              allow(Flipper).to receive(:enabled?).with(:accredited_representative_portal_api).and_return(enabled)
            end

            context 'is enabled' do
              let(:enabled) { true }

              it { is_expected.to have_http_status(:ok) }
            end

            context 'is disabled' do
              let(:enabled) { false }

              it { is_expected.to have_http_status(:not_found) }
            end
          end
        end

        context 'when the representative is not found' do
          let(:expected_response_body) do
            { errors: 'User is not a VA representative' }.to_json
          end
          let(:expected_error) { 'User is not a VA representative' }
          let(:expected_log_payload) { { access_token_cookie: } }

          before do
            allow(Rails.logger).to receive(:error)
          end

          it 'raises a representative record not found error' do
            expect(subject).to have_http_status(:unauthorized)
            expect(subject.body).to eq(expected_response_body)
            expect(Rails.logger).to have_received(:error).with("#{expected_error} : #{expected_log_payload.to_s}")
          end
        end
      end

      context 'with an invalid audience' do
        let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: invalid_access_token).perform }
        let(:expected_log_message) { '[SignIn::AudienceValidator] Invalid audience' }
        let(:expected_log_payload) do
          { invalid_audience: invalid_access_token.audience, valid_audience: valid_access_token.audience }
        end
        let(:expected_response_body) do
          { errors: 'Invalid audience' }.to_json
        end

        before do
          allow(Rails.logger).to receive(:error)
        end

        it 'denies access' do
          expect(subject).to have_http_status(:unauthorized)
          expect(subject.body).to eq(expected_response_body)
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end
  end
end

module AccreditedRepresentativePortal
  class ArbitraryController < ApplicationController
    def arbitrary = head :ok
  end
end
