# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationCareerCounselingClaimsController, type: :controller do
  let(:user) { create(:evss_user) }

  let(:test_form_no_vet_info) do
    build(:education_career_counseling_claim_no_vet_information)
  end

  let(:test_form) do
    build(:education_career_counseling_claim)
  end

  describe 'POST create' do
    context 'logged in user' do
      it 'validates successfully' do
        sign_in_as(user)
        form_params = { education_career_counseling_claim: { form: test_form_no_vet_info.form } }

        post(:create, params: form_params)
        expect(response.code).to eq('200')
      end
    end

    context 'visitor' do
      it 'validates successfully' do
        form_params = { education_career_counseling_claim: { form: test_form.form } }

        post(:create, params: form_params)
        expect(response.code).to eq('200')
      end
    end

    context 'with invalid params' do
      it 'shows the validation errors' do
        post(:create, params: { education_career_counseling_claim: { form: { not_valid: 'not valid' } } })

        expect(response.code).to eq('422')

        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - can\'t be blank'
          )
        ).to eq(true)
      end
    end
  end
end
