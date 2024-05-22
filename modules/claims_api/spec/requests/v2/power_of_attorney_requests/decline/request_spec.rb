# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

RSpec.describe 'Power Of Attorney Requests: decline', :bgs, type: :request do
  cassette_directory =
    Pathname.new(
      # This mirrors the path to this spec file. It could be convenient to keep
      # that in sync in case this file moves.
      'claims_api/requests/v2/power_of_attorney_requests/decline/request_spec'
    )

  subject do
    put(
      "/services/claims/v2/power-of-attorney-requests/#{id}/decision",
      params: params.to_json,
      headers:
    )
  end

  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  let(:scopes) do
    %w[
      system/system/claim.write
      system/claim.read
    ]
  end

  describe 'with a valid decline with reason' do
    let(:id) { '600082088_3854887' }

    let(:params) do
      {
        'decision' => {
          'status' => 'Declined',
          'declinedReason' => 'Some reason',
          'representative' => {
            'firstName' => 'BEATRICE',
            'lastName' => 'STROUD',
            'email' => 'Beatrice.Stroud44@va.gov'
          }
        }
      }
    end

    it 'responds no_content', run_at: '2024-05-09T07:18:04Z' do
      mock_ccg(scopes) do
        use_soap_cassette(cassette_directory / 'valid_decline_with_reason') do
          subject
        end
      end

      expect(response).to(
        have_http_status(:no_content)
      )
    end
  end
end
