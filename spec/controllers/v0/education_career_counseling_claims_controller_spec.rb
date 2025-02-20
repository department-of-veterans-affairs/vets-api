# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationCareerCounselingClaimsController, type: :controller do
  let(:loa3_user) { create(:evss_user) }
  let(:loa1_user) { create(:user) }

  let(:test_form) do
    build(:education_career_counseling_claim)
  end

  describe 'POST create' do
    context 'logged in loa3 user' do
      let(:form_params) { { education_career_counseling_claim: { form: test_form.form } } }

      before { sign_in_as(loa3_user) }

      it 'validates successfully' do
        post(:create, params: form_params)

        expect(response).to have_http_status(:ok)
      end

      it 'calls successfully submits the career counseling job' do
        expect(Lighthouse::SubmitCareerCounselingJob).to receive(:perform_async)

        post(:create, params: form_params)
      end
    end

    context 'visitor' do
      it 'validates successfully' do
        form_params = { education_career_counseling_claim: { form: test_form.form } }

        post(:create, params: form_params)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      it 'shows the validation errors' do
        post(:create, params: { education_career_counseling_claim: { form: { not_valid: 'not valid' } } })

        expect(response).to have_http_status(:unprocessable_entity)

        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - can\'t be blank'
          )
        ).to be(true)
      end
    end
  end
end
