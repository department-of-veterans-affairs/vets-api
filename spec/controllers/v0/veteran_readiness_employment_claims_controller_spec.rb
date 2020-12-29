# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VeteranReadinessEmploymentClaimsController, type: :controller do
  let(:user) { create(:evss_user) }

  let(:test_form_no_vet_info) do
    build(:veteran_readiness_employment_claim_no_vet_information)
  end

  let(:test_form) do
    build(:veteran_readiness_employment_claim)
  end

  describe 'POST create' do
    context 'logged in user' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          sign_in_as(user)
          form_params = { veteran_readiness_employment_claim: { form: test_form.form } }

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end
    end

    context 'visitor' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          form_params = { veteran_readiness_employment_claim: { form: test_form.form } }

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end
    end

    context 'with invalid params' do
      it 'shows the validation errors' do
        post(:create, params: { veteran_readiness_employment_claim: { form: { not_valid: 'not valid' } } })

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
