# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

RSpec.describe 'decision letters', type: :request do
  include JsonSchemaMatchers

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(FakeVBMS.new)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
  end

  # This endpoint's upstream service mocks it's own data for test env. HTTP client is not exposed by the
  # connect_vbms gem so it cannot intercept the actual HTTP request, making the use of VCRs not possible.
  # This means we cannot test error states for the index endpoint within specs
  describe 'GET /mobile/v0/decision_letters' do
    context 'with a valid response' do
      it 'returns expected decision letters' do
        get '/mobile/v0/claims/decision_letters', headers: iam_headers
        expect(response).to have_http_status(:ok)
        decision_letters = response.parsed_body['data']
        first_received_at = decision_letters.first.dig('attributes', 'receivedAt')
        last_received_at = decision_letters.last.dig('attributes', 'receivedAt')

        expect(decision_letters.count).to eq(5)
        expect(first_received_at).to be >= last_received_at
        expect(response.body).to match_json_schema('decision_letter')
      end
    end
  end
end
