# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Burial Claim Integration' do
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
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
      end

      let(:params) do
        {
          burialClaim: {
            form: full_claim.merge('claimantAddress' => 'just a string').to_json
          }
        }
      end

      it 'shows the validation errors' do
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

      # need run_at and uuid for VCR cassette to match
      it 'renders success', run_at: 'Thu, 29 Aug 2019 17:45:03 GMT' do
        allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

        VCR.use_cassette(
          'mvi/find_candidate/find_profile_with_attributes',
          VCR::MATCH_EVERYTHING
        ) do
          subject
          expect(JSON.parse(response.body)['data']['attributes'].keys.sort)
            .to eq(%w[confirmationNumber form guid regionalOffice submittedAt])
        end
      end
    end
  end
end
