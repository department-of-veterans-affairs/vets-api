# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Education Benefits Claims Integration', type: [:request, :serializer] do
  describe 'POST create' do
    subject do
      post(
        v0_education_benefits_claims_path,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

    context 'with valid params' do
      let(:params) do
        {
          educationBenefitsClaim: {
            form: { preferredContactMethod: 'mail' }.to_json
          }
        }
      end

      it 'should create a new model' do
        expect { subject }.to change { EducationBenefitsClaim.count }.by(1)
        expect(EducationBenefitsClaim.last.parsed_form['preferredContactMethod']).to eq('mail')
      end

      it 'should render json of the new model' do
        subject

        expect(response.body).to eq(
          JSON.parse(serialize(EducationBenefitsClaim.last)).to_camelback_keys.to_json
        )
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          educationBenefitsClaim: { form: nil }
        }
      end

      it 'should render json of the errors' do
        subject
        expect(response.code).to eq('422')
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
          "form - can't be blank"
        )
      end

      it 'should log the validation errors' do
        education_benefits_claim = EducationBenefitsClaim.new(params[:educationBenefitsClaim])
        education_benefits_claim.valid?
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(validation_error).once

        expect(Raven).to receive(:tags_context).once.with(validation: 'education_benefits_claim')
        expect(Raven).to receive(:capture_exception).once.with(validation_error)

        subject
      end
    end
  end
end
