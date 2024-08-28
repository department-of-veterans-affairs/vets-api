# frozen_string_literal: true

require 'rails_helper'

reg_office = 'Department of Veteran Affairs, Pension Intake Center, P.O. Box 5365, Janesville, Wisconsin 53547-5365'

RSpec.describe 'V0::PensionClaims', type: %i[request serializer] do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

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
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/bankAccount' of type string"
          )
        ).to eq(true)
      end

      it 'logs the attempted submission' do
        expect(Rails.logger).to receive(:info).with('21P-527EZ submission to Sidekiq begun', be_a(Hash))
        expect(Rails.logger).to receive(:error).with('Validation error.')
        subject
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

      it 'logs the successful submission' do
        expect(Rails.logger).to receive(:info).with('21P-527EZ submission to Sidekiq begun', be_a(Hash))
        expect(Rails.logger).to receive(:info).with('21P-527EZ submission to Sidekiq success', be_a(Hash))
        subject
      end

      it 'returns the expected regional office' do
        subject
        expect(JSON.parse(response.body)['data']['attributes']['regionalOffice'].join(', '))
          .to eq(reg_office)
      end
    end
  end
end
