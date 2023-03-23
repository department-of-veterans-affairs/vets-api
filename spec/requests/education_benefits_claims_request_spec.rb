# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Education Benefits Claims Integration', type: %i[request serializer] do
  describe 'POST create' do
    subject do
      post(path,
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' })
    end

    let(:path) { v0_education_benefits_claims_path }

    context 'with a form_type passed in' do
      let(:form_type) { '1995' }
      let(:params) do
        {
          educationBenefitsClaim: {
            form: build(:va1995).form
          }
        }
      end

      let(:path) do
        form_type_v0_education_benefits_claims_path(form_type:)
      end

      it 'creates a 1995 form' do
        expect { subject }.to change(EducationBenefitsClaim, :count).by(1)
        expect(EducationBenefitsClaim.last.form_type).to eq(form_type)
      end

      it 'increments statsd' do
        expect { subject }.to trigger_statsd_increment('api.education_benefits_claim.221995.success')
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          educationBenefitsClaim: {
            form: {
              privacyAgreementAccepted: true,
              veteranFullName: {
                first: 'Mark',
                last: 'Olson'
              },
              preferredContactMethod: 'mail'
            }.to_json
          }
        }
      end

      it 'creates a new model' do
        expect { subject }.to change(EducationBenefitsClaim, :count).by(1)
        expect(EducationBenefitsClaim.last.parsed_form['preferredContactMethod']).to eq('mail')
      end

      it 'clears the saved form' do
        expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('22-1990').once
        subject
      end

      it 'renders json of the new model' do
        subject
        expect(response.body).to eq(
          JSON.parse(
            serialize(EducationBenefitsClaim.last)
          ).deep_transform_keys { |key| key.underscore.camelize(:lower) }.to_json
        )
      end

      it 'increments statsd' do
        expect { subject }.to trigger_statsd_increment('api.education_benefits_claim.221990.success')
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          educationBenefitsClaim: { form: nil }
        }
      end

      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      it 'renders json of the errors' do
        subject
        expect(response.code).to eq('422')
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
          "form - can't be blank"
        )
      end

      it 'increments statsd' do
        expect { subject }.to trigger_statsd_increment('api.education_benefits_claim.221990.failure')
      end
    end
  end
end
