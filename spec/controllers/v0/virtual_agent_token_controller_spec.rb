# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VirtualAgentTokenController, type: :controller do
  describe '#create' do
    context 'when external service is healthy' do
      let(:recorded_token) do
        'ew0KICAiYWxnIjogIlJTMjU2IiwNCiAgImtpZCI6ICJsY0oxTXFpNkdKYXdCZEw5Y0dieEt5S1R6OE0iLA0KICAieDV0IjogImxjSjFNcWk2' \
        'R0phd0JkTDljR2J4S3lLVHo4TSIsDQogICJ0eXAiOiAiSldUIg0KfQ.ew0KICAiYm90IjogInZhYm90LWF6Y2N0b2xhYi1ib3QiLA0KICAic' \
        '2l0ZSI6ICJ3b1ZDYXV2RzA2QSIsDQogICJjb252IjogIjdPajBBbzJ2bWxpTGZxRFZRZGpOME0tNiIsDQogICJuYmYiOiAxNjE1NTg0MDcyL' \
        'A0KICAiZXhwIjogMTYxNTU4NzY3MiwNCiAgImlzcyI6ICJodHRwczovL2RpcmVjdGxpbmUuYm90ZnJhbWV3b3JrLmNvbS8iLA0KICAiYXVkI' \
        'jogImh0dHBzOi8vZGlyZWN0bGluZS5ib3RmcmFtZXdvcmsuY29tLyINCn0.kqUZA7Awnh0gFDDvJN87Kl1wOUNZLjZaYMu14JWeK3tvF60g-' \
        'iMsc3anM67hVC1hZ-WqJ4Aowm06LsYZ0ZF3baAFUi70r0B6s0-GMwtQ75V34Ee3vDp4u4t-wm2fFuMoGinJ-PBZPTAHV5QaOnkzVblEPL5L2' \
        'PmIDDt_uFQ32aFuEdRpX02rKyhiD_Y5r_y0gSW3elUGvxVJTsKvl1qgY6WoGp6f_60HkTZOKr49lyqgz2Hfp0t_qHcpyI208aP1SpLzUpDSh' \
        'MzZk-oyzGPlep8XDOTNl54nBL__q7NlZu8VMKxhX7IlBjchGcYzZXCD9w6ZfLgsJHp-ftB7HJUEug'
      end

      it 'returns a token' do
        VCR.use_cassette('virtual_agent/webchat_token') do
          post :create
        end

        expect(response).to have_http_status(:ok)

        res = JSON.parse(response.body)
        expect(res['token']).to eq(recorded_token)
      end
    end

    context 'when external service is unavailable' do
      it 'returns service unavailable' do
        VCR.use_cassette('virtual_agent/webchat_error') do
          post :create
        end

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
