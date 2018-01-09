# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Education Benefits Claims Integration', type: [:request, :serializer] do
  describe 'POST create' do
    let(:path) { v0_education_benefits_claims_path }

    subject do
      post(
        path,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

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
        form_type_v0_education_benefits_claims_path(form_type: form_type)
      end

      it 'should create a 1995 form' do
        expect { subject }.to change { EducationBenefitsClaim.count }.by(1)
        expect(EducationBenefitsClaim.last.form_type).to eq(form_type)
      end

      it 'should increment statsd' do
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
                "first": 'Mark',
                "last": 'Olson'
              },
              preferredContactMethod: 'mail'
            }.to_json
          }
        }
      end

      it 'should create a new model' do
        expect { subject }.to change { EducationBenefitsClaim.count }.by(1)
        expect(EducationBenefitsClaim.last.parsed_form['preferredContactMethod']).to eq('mail')
      end

      it 'should clear the saved form' do
        expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('22-1990').once
        subject
      end

      it 'should render json of the new model' do
        subject
        expect(response.body).to eq(
          JSON.parse(serialize(EducationBenefitsClaim.last)).to_camelback_keys.to_json
        )
      end

      it 'should increment statsd' do
        expect { subject }.to trigger_statsd_increment('api.education_benefits_claim.221990.success')
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          educationBenefitsClaim: { form: nil }
        }
      end
      before { Settings.sentry.dsn = 'asdf' }
      after { Settings.sentry.dsn = nil }

      it 'should render json of the errors' do
        subject
        expect(response.code).to eq('422')
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
          "form - can't be blank"
        )
      end

      it 'should log the validation errors' do
        education_benefits_claim = SavedClaim::EducationBenefits::VA1990.new(params[:educationBenefitsClaim])
        education_benefits_claim.valid?
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(validation_error).once

        expect(Raven).to receive(:tags_context).once.with(validation: 'education_benefits_claim')
        expect(Raven).to receive(:capture_message).once.with(validation_error, level: :error)

        subject
      end

      it 'should increment statsd' do
        expect { subject }.to trigger_statsd_increment('api.education_benefits_claim.221990.failure')
      end
    end
  end
end
