# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dependents Application Integration', type: %i[request serializer] do
  let(:test_form) do
    JSON.parse(
      File.read(
        Rails.root.join('spec', 'fixtures', 'dependents', 'test_form.json')
      )
    )
  end

  describe 'POST create' do
    subject do
      post(
        v0_dependents_applications_path,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

    context 'with valid params' do
      let(:params) do
        {
          form: test_form.to_json
        }
      end

      it 'should validate successfully' do
        subject
        expect(response.code).to eq('200')
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          form: test_form.except('privacyAgreementAccepted').to_json
        }
      end

      it 'should show the validation errors' do
        subject

        expect(response.code).to eq('422')
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
          )
        ).to eq(true)
      end
    end
  end
end
