# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe ApplicationController, type: :request do
    let(:monitor) { instance_double(Monitoring::Service) }

    before do
      allow(Monitoring::Service).to receive(:new).and_return(monitor)
      allow(monitor).to receive(:track_error)
    end

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
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
        Engine.routes.draw do
          get 'arbitrary', to: 'arbitrary#arbitrary'
        end
      end

      after do
        Rails.application.reload_routes!
      end

      context 'when authenticated' do
        context 'with a valid audience' do
          it 'allows access and tracks the request' do
            expect(subject).to have_http_status(:ok)
          end
        end

        context 'with an invalid audience' do
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: invalid_access_token).perform }
          let(:expected_log_message) { '[SignIn][AudienceValidator] Invalid audience' }
          let(:expected_log_payload) do
            {
              invalid_audience: invalid_access_token.audience,
              valid_audience: [arp_client_id]
            }
          end
          let(:expected_response_body) { { errors: 'Invalid audience' }.to_json }

          before do
            allow(Rails.logger).to receive(:error)
          end

          it 'denies access and tracks the failure' do
            expect(subject).to have_http_status(:unauthorized)
            expect(subject.body).to eq(expected_response_body)
            expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
          end
        end
      end
    end
  end

  class ArbitraryController < ApplicationController
    skip_before_action :verify_pilot_enabled_for_user
    skip_after_action :verify_pundit_authorization

    def arbitrary
      head :ok
    end
  end
end
