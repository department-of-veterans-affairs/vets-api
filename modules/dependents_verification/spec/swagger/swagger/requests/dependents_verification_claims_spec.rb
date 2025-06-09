# frozen_string_literal: true

require 'rails_helper'

reg_office = 'Department of Veteran Affairs, Example Address, P.O. Box 0000, Janesville, Wisconsin 53547-5365'

# Dependents Verification Claim Integration
RSpec.describe Swagger::Requests::DependentsVerificationClaims, type: %i[request serializer] do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  let(:full_claim) do
    build(:dependents_verification_claim).parsed_form
  end

  describe 'POST create' do
    subject do
      post '/dependents_verification/v0/form0538',
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' }
    end

    context 'with invalid params' do
      before do
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
      end

      let(:params) do
        {
          dependentsVerificationClaim: {
            form: full_claim.merge('veteranSocialSecurityNumber' => 'just a string').to_json
          }
        }
      end

      it 'shows the validation errors', pending: 'No vets-json-schema validation yet' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)

        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            '/veteran-social-security-number - string at `/veteranSocialSecurityNumber` ' \
            'does not match pattern: ^[0-9]{9}$'
          )
        ).to be(true)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          dependentsVerificationClaim: {
            form: full_claim.to_json
          }
        }
      end

      it 'renders success' do
        subject
        expect(JSON.parse(response.body)['data']['attributes'].keys.sort)
          .to eq(%w[confirmationNumber form guid regionalOffice submittedAt])
      end

      it 'returns the expected regional office' do
        subject
        expect(JSON.parse(response.body)['data']['attributes']['regionalOffice'].join(', '))
          .to eq(reg_office)
      end
    end
  end
end
