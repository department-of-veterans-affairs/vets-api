# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DependentsApplicationsController do
  include AuthenticatedSessionHelper
  let(:user) { create(:evss_user) }

  before do
    use_authenticated_current_user(current_user: user)
  end

  let(:test_form) do
    JSON.parse(
      File.read(
        Rails.root.join('spec', 'fixtures', 'dependents', 'test_form.json')
      )
    )
  end

  describe '#show' do
    let(:dependents_application) { create(:dependents_application) }

    it 'should return a dependents application' do
      binding.pry; fail
      get(:show, id: dependents_application.id)
      binding.pry; fail
    end
  end

  describe 'POST create' do
    subject do
      post(:create, params)
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
end
