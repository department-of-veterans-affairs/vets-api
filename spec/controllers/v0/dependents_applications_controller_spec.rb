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
    context 'with a valid bgs response' do
      let(:user) { build(:disabilities_compensation_user, ssn: '796126777') }

      it 'returns a list of dependents' do
        VCR.use_cassette('bgs/claimant_web_service/dependents') do
          get(:show, params: { id: user.participant_id })
          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['type']).to eq('dependents')
        end
      end
    end

    context 'with an empty bgs response' do
      let(:user) { build(:disabilities_compensation_user, ssn: '796043735') }

      it 'returns no content' do
        allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_raise(BGS::ShareError)
        get(:show, params: { id: user.participant_id })
        expect(response.code).to eq('400')
        expect(response).to have_http_status(:bad_request)
      end
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

      it 'validates successfully' do
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

      it 'shows the validation errors' do
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
