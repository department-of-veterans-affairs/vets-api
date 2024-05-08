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
      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      end

      context 'with a valid audience' do
        it 'allows access' do
          expect(subject).to have_http_status(:ok)
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
