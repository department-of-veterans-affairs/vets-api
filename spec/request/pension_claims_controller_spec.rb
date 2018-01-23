# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

RSpec.describe 'Pension Claim Integration', type: %i[request serializer] do
  let(:full_claim) do
    build(:pension_claim).parsed_form
  end

  describe 'POST create' do
    subject do
      post(
        v0_pension_claims_path,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

    context 'with invalid params' do
      before do
        Settings.sentry.dsn = 'asdf'
      end
      after do
        Settings.sentry.dsn = nil
      end
      let(:params) do
        # JSON.parse(response.body)['errors']
        {
          pensionClaim: {
            form: full_claim.merge('bankAccount' => 'just a string').to_json
          }
        }
      end

      it 'should show the validation errors' do
        subject
        expect(response.code).to eq('422')
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/bankAccount' of type String"
          )
        ).to eq(true)
      end

      it 'should log the validation errors' do
        expect(Raven).to receive(:tags_context).once.with(
          controller_name: 'pension_claims',
          sign_in_method: 'not-signed-in'
        )
        expect(Raven).to receive(:tags_context).once.with(validation: 'pension_claim')
        expect(Raven).to receive(:capture_message).with(/bankAccount/, level: :error)

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
      it 'should render success' do
        subject
        expect(JSON.parse(response.body)['data']['attributes'].keys.sort)
          .to eq(%w[confirmationNumber form regionalOffice submittedAt])
      end
    end
  end
end
