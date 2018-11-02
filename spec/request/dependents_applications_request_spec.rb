# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dependents Application Integration', type: %i[request serializer] do
  let(:user) { build(:user, :loa3) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
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

  describe 'GET disability_rating' do
    before do
      Session.create(uuid: user.uuid, token: token)
      User.create(user)
    end

    it "returns the user's disability rating" do
      VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
        get(disability_rating_v0_dependents_applications_path, nil, 'Authorization' => "Token token=#{token}")
        expect(response.code).to eq('200')
        expect(JSON.parse(response.body)['has30_percent']).to be true
      end
    end
  end
end
