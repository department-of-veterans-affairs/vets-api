# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DependentsApplicationsController do
  let(:user) { create(:evss_user) }

  before do
    sign_in_as(user)
  end

  let(:test_form_v2) do
    build(:dependency_claim_v2).parsed_form
  end

  let(:service) { instance_double(BGS::DependentService) }
  let(:service_v2) { instance_double(BGS::DependentService) }

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
    context 'with valid params' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
      end

      it 'validates successfully' do
        expect(BGS::DependentService).to receive(:new)
          .with(instance_of(User))
          .and_return(service_v2)

        expect(service_v2).to receive(:submit_686c_form)
          .with(instance_of(SavedClaim::DependencyClaim))

        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post(:create, params: test_form_v2, as: :json)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'sets the user account on the claim' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post(:create, params: test_form_v2, as: :json)
        end
        claim = SavedClaim::DependencyClaim.last
        expect(claim.user_account).to eq(user.user_account)
      end

      context 'when claim is pension related' do
        it 'tracks pension related submission' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pension_related_submission?).and_return(true)

          monitor_double = instance_double(Dependents::Monitor)
          allow_any_instance_of(V0::DependentsApplicationsController).to receive(:monitor).and_return(monitor_double)
          allow(monitor_double).to receive(:track_create_attempt)
          allow(monitor_double).to receive(:track_create_success)
          allow(monitor_double).to receive(:track_pension_related_submission)

          expect(monitor_double)
            .to receive(:track_pension_related_submission)
            .with(form_id: '686C-674-V2', form_type: '686c-674')

          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            post(:create, params: test_form_v2, as: :json)
          end
        end
      end

      context 'when claim is not pension related' do
        it 'does not track pension related submission' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pension_related_submission?).and_return(false)

          monitor_double = instance_double(Dependents::Monitor)
          allow_any_instance_of(V0::DependentsApplicationsController).to receive(:monitor).and_return(monitor_double)
          allow(monitor_double).to receive(:track_create_attempt)
          allow(monitor_double).to receive(:track_create_success)

          expect(monitor_double).not_to receive(:track_pension_related_submission)

          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            post(:create, params: test_form_v2, as: :json)
          end
        end
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
