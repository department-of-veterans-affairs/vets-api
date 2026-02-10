# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::V0::ClaimsController, type: :controller do
  routes { VRE::Engine.routes }

  let(:loa3_user) { create(:evss_user) }
  let(:user_no_pid) { create(:unauthorized_evss_user) }

  let(:test_form) do
    build(:veteran_readiness_employment_claim)
  end

  let(:no_veteran_info) do
    hash_copy = JSON.parse(
      test_form.form
    )

    hash_copy['veteranInformation'] = nil
    hash_copy.to_json
  end

  describe 'POST create' do
    context 'logged in user' do
      before { sign_in_as(loa3_user) }

      it 'validates successfully' do
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        expect { post(:create, params: form_params) }.to change(VRE::VRESubmit1900Job.jobs, :size).by(1)
        expect(response).to have_http_status(:ok)
      end

      it 'fails validation when no veteran_info is passed in' do
        form_params = { veteran_readiness_employment_claim: { form: no_veteran_info } }
        post(:create, params: form_params)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'shows the validation errors' do
        post(:create, params: { veteran_readiness_employment_claim: { form: { not_valid: 'not valid' } } })
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - can\'t be blank'
          )
        ).to be(true)
      end

      it 'associates the claim with the user_account' do
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        post(:create, params: form_params)

        claim = SavedClaim::VeteranReadinessEmploymentClaim.last
        expect(claim.user_account).to eq(loa3_user.user_account)
      end
    end

    context 'logged in user with missing user_account' do
      before { sign_in_as(loa3_user) }

      it 'creates claim without user_account when user_account does not exist' do
        UserAccount.find_by(icn: loa3_user.icn)&.destroy

        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        post(:create, params: form_params)

        claim = SavedClaim::VeteranReadinessEmploymentClaim.last
        expect(claim.user_account).to be_nil
      end
    end

    context 'logged in user with no pid' do
      it 'validates successfully' do
        sign_in_as(user_no_pid)
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        expect { post(:create, params: form_params) }.to change(VRE::VRESubmit1900Job.jobs, :size).by(1)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'visitor' do
      it 'returns a 401' do
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        post(:create, params: form_params)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
