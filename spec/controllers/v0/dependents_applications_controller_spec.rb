# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DependentsApplicationsController do
  let(:user) { create(:evss_user) }

  before do
    sign_in_as(user)
  end

  let(:test_form) do
    build(:dependency_claim).parsed_form
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

    context 'with an erroneous bgs response' do
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
    context 'with valid params' do
      before do
        allow(VBMS::SubmitDependentsPdfJob).to receive(:perform_sync)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
      end

      it 'validates successfully' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post(:create, params: test_form)
        end

        expect(response.code).to eq('200')
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          dependents_application: {}
        }
      end

      it 'shows the validation errors' do
        post(:create, params:)

        expect(response.code).to eq('422')
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'Veteran address can\'t be blank'
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
