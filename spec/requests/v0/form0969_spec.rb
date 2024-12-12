# frozen_string_literal: true

reg_office = 'Department of Veteran Affairs, Pension Intake Center, P.O. Box 5365, Janesville, Wisconsin 53547-5365'

# Income and Assets Claim Integration
RSpec.describe 'V0::Form0969', type: %i[request serializer] do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  let(:full_claim) do
    build(:income_and_assets_claim).parsed_form
  end

  describe 'POST create' do
    subject do
      post('/v0/form0969',
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' })
    end

    context 'with invalid params' do
      before do
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
        # This needs to be modernized (using allow)
        Flipper.disable(:validate_saved_claims_with_json_schemer)
      end

      let(:params) do
        {
          incomeAndAssetsClaim: {
            form: full_claim.merge('veteranSocialSecurityNumber' => 'just a string').to_json
          }
        }
      end

      it 'shows the validation errors' do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/veteranSocialSecurityNumber' value \"just a string\" did not match the regex"
          )
        ).to eq(true)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          incomeAndAssetsClaim: {
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
