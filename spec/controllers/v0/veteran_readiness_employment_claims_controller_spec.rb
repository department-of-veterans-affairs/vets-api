# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'claims_api/vbms_uploader'

RSpec.describe V0::VeteranReadinessEmploymentClaimsController, type: :controller do
  let(:loa3_user) { create(:evss_user) }
  let(:user_no_pid) { create(:unauthorized_evss_user) }

  let(:test_form) do
    build(:veteran_readiness_employment_claim)
  end
  let(:new_test_form) do
    build(:veteran_readiness_employment_claim)
  end

  let(:no_veteran_info) do
    hash_copy = JSON.parse(
      test_form.form
    )

    hash_copy['veteranInformation'] = nil
    hash_copy.to_json
  end

  describe 'POST create with vre_modular_api feature toggle enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:vre_modular_api).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:vre_track_submissions).and_return(false)
    end

    context 'logged in user with vre_modular_api feature toggle enabled' do
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
    end

    context 'logged in user with new form' do
      before { sign_in_as(loa3_user) }

      it 'validates successfully' do
        form_params = { form: new_test_form.form }
        expect { post(:create, params: form_params) }.to change(VRE::VRESubmit1900Job.jobs, :size).by(1)
        expect(response).to have_http_status(:ok)
      end

      it 'shows the validation errors' do
        post(:create, params: { form: { not_valid: 'not valid' } })
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - can\'t be blank'
          )
        ).to be(true)
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

    context 'logged in user with no pid and new form' do
      it 'validates successfully' do
        sign_in_as(user_no_pid)
        form_params = { form: new_test_form.form }
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

    context 'visitor with new form' do
      it 'returns a 401' do
        form_params = { form: new_test_form.form }
        post(:create, params: form_params)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST create with vre_modular_api feature toggle disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:vre_track_submissions).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:vre_modular_api).and_return(false)
    end

    context 'logged in user' do
      before { sign_in_as(loa3_user) }

      it 'validates successfully' do
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        expect { post(:create, params: form_params) }.to change(VRE::Submit1900Job.jobs, :size).by(1)
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
    end

    context 'logged in user with new form' do
      before { sign_in_as(loa3_user) }

      it 'validates successfully' do
        form_params = { form: new_test_form.form }
        expect { post(:create, params: form_params) }.to change(VRE::Submit1900Job.jobs, :size).by(1)
        expect(response).to have_http_status(:ok)
      end

      it 'shows the validation errors' do
        post(:create, params: { form: { not_valid: 'not valid' } })
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - can\'t be blank'
          )
        ).to be(true)
      end
    end

    context 'logged in user with no pid' do
      it 'validates successfully' do
        sign_in_as(user_no_pid)
        form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
        expect { post(:create, params: form_params) }.to change(VRE::Submit1900Job.jobs, :size).by(1)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'logged in user with no pid and new form' do
      it 'validates successfully' do
        sign_in_as(user_no_pid)
        form_params = { form: new_test_form.form }
        expect { post(:create, params: form_params) }.to change(VRE::Submit1900Job.jobs, :size).by(1)
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

    context 'visitor with new form' do
      it 'returns a 401' do
        form_params = { form: new_test_form.form }
        post(:create, params: form_params)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST create with vre_track_submissions feature flag' do
    let(:form_params) { { veteran_readiness_employment_claim: { form: test_form.form } } }

    before do
      sign_in_as(loa3_user)
      # Set modular API flag to true so we're testing VRESubmit1900Job
      allow(Flipper).to receive(:enabled?).with(:vre_modular_api).and_return(true)
    end

    context 'when vre_track_submissions is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:vre_track_submissions).and_return(true)
      end

      it 'creates a FormSubmission record' do
        expect { post(:create, params: form_params) }
          .to change(FormSubmission, :count).by(1)
      end

      it 'associates FormSubmission with user_account' do
        post(:create, params: form_params)

        submission = FormSubmission.last
        expect(submission.user_account).to eq(loa3_user.user_account)
      end

      it 'sets correct form_type on FormSubmission' do
        post(:create, params: form_params)

        submission = FormSubmission.last
        expect(submission.form_type).to eq('28-1900-V2')
      end

      it 'passes FormSubmission ID to job as third argument' do
        post(:create, params: form_params)

        job_args = VRE::VRESubmit1900Job.jobs.last['args']
        submission_id = FormSubmission.last.id
        expect(job_args[2]).to eq(submission_id)
      end

      it 'handles missing user_account gracefully' do
        UserAccount.find_by(icn: loa3_user.icn)&.destroy

        expect { post(:create, params: form_params) }
          .to change(FormSubmission, :count).by(1)

        submission = FormSubmission.last
        expect(submission.user_account).to be_nil
      end
    end

    context 'when vre_track_submissions is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:vre_track_submissions).and_return(false)
      end

      it 'does not create a FormSubmission record' do
        expect { post(:create, params: form_params) }
          .not_to change(FormSubmission, :count)
      end

      it 'passes nil as submission_id to job' do
        post(:create, params: form_params)

        job_args = VRE::VRESubmit1900Job.jobs.last['args']
        expect(job_args[2]).to be_nil
      end

      it 'still creates the claim successfully' do
        post(:create, params: form_params)

        expect(response).to have_http_status(:ok)
        expect(SavedClaim::VeteranReadinessEmploymentClaim.count).to eq(1)
      end
    end
  end
end
