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
          expect(response).to have_http_status(:ok)
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
        expect(response).to have_http_status(:bad_request)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST create' do
    context 'with valid params v1' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_separate_confirmation_email).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:dependents_submitted_email).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        allow(VBMS::SubmitDependentsPdfJob).to receive(:perform_sync)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:confirmation_number).and_return('')
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
      end

      it 'validates successfully' do
        expect(VANotify::EmailJob).to receive(:perform_async) do |email, template_id, personalization, secret|
          expect(email).to_be(user.va_profile_email)
          expect(template_id).to_be('fake_submitted686c674')
          expect(personalization).to_have.keys(%w[date_submitted first_name confirmation_number])
          expect(secret).to_be('fake_secret')
        end
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post(:create, params: test_form)
        end
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with valid params v2' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        allow(VBMS::SubmitDependentsPdfJob).to receive(:perform_sync)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
      end

      it 'validates successfully' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post(:create, params: test_form)
        end
        expect(response).to have_http_status(:ok)
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

        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'Veteran address can\'t be blank'
          )
        ).to be(true)
      end
    end
  end
end
