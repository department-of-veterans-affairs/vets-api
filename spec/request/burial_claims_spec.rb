# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

RSpec.describe 'Burial Claim Integration', type: %i[request serializer] do
  let(:full_claim) do
    build(:burial_claim).parsed_form
  end

  describe 'POST create' do
    subject do
      post(v0_burial_claims_path,
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' })
    end

    context 'with invalid params' do
      before do
        Settings.sentry.dsn = 'asdf'
      end
      after do
        Settings.sentry.dsn = nil
      end
      let(:params) do
        {
          burialClaim: {
            form: full_claim.merge('claimantAddress' => 'just a string').to_json
          }
        }
      end

      it 'should show the validation errors' do
        subject
        expect(response.code).to eq('422')
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/claimantAddress' of type string"
          )
        ).to eq(true)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          burialClaim: {
            form: full_claim.to_json
          }
        }
      end
      it 'should render success' do
        subject
        expect(JSON.parse(response.body)['data']['attributes'].keys.sort)
          .to eq(%w[confirmationNumber form guid regionalOffice submittedAt])
      end
    end
  end
end
