# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DependentsApplicationsController do
  let(:user) { create(:evss_user) }

  before do
    sign_in_as(user)
  end

  let(:test_form) do
    build(:dependents_application).parsed_form
  end

  describe '#show' do
    let(:dependents_application) { create(:dependents_application) }

    it 'should return a dependents application' do
      id = dependents_application.id
      get(:show, params: { id: id })
      expect(JSON.parse(response.body)['data']['id']).to eq id
    end
  end

  describe 'POST create' do
    subject do
      post(:create, params: params)
    end

    context 'with valid params' do
      let(:params) do
        {
          dependents_application: {
            form: test_form.to_json
          }
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
          dependents_application: {
            form: test_form.except('privacyAgreementAccepted').to_json
          }
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
    it "returns the user's disability rating" do
      VCR.use_cassette('evss/dependents/retrieve_user_with_max_attributes') do
        get(:disability_rating)
        expect(response.code).to eq('200')
        expect(JSON.parse(response.body)['has30_percent']).to be true
      end
    end
  end
end
