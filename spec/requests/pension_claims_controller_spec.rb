# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pension Claim Integration', type: %i[request serializer] do
  let(:full_claim) do
    build(:pension_claim).parsed_form
  end

  describe 'POST create' do
    subject do
      post(v0_pension_claims_path,
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' })
    end

    context 'with invalid params' do
      before do
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
      end

      let(:params) do
        # JSON.parse(response.body)['errors']
        {
          pensionClaim: {
            form: full_claim.merge('bankAccount' => 'just a string').to_json
          }
        }
      end

      it 'shows the validation errors' do
        subject
        expect(response.code).to eq('422')
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/bankAccount' of type string"
          )
        ).to eq(true)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          pensionClaim: {
            form: full_claim.to_json
          }
        }
      end

      it 'renders success' do
        subject
        expect(JSON.parse(response.body)['data']['attributes'].keys.sort)
          .to eq(%w[confirmationNumber form guid regionalOffice submittedAt])
      end
    end
  end
end
