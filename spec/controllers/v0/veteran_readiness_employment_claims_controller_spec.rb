# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VeteranReadinessEmploymentClaimsController, type: :controller do
  let(:loa3_user) { create(:evss_user) }
  let(:loa1_user) { create(:user) }

  let(:test_form_no_vet_info) do
    build(:veteran_readiness_employment_claim_no_vet_information)
  end

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
    context 'logged in as loa3 user' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          sign_in_as(loa3_user)

          form_params = { veteran_readiness_employment_claim: { form: no_veteran_info } }

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end
    end

    context 'logged in as loa1 user' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          sign_in_as(loa1_user)

          form_params = { veteran_readiness_employment_claim: { form: test_form.form } }

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end

      it 'fails validation when no veteran_info is passed in' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          sign_in_as(loa1_user)

          form_params = { veteran_readiness_employment_claim: { form: no_veteran_info } }

          post(:create, params: form_params)
          expect(response.code).to eq('422')
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

      it 'fails validation when no veteran_info is passed in' do
        form_params = { veteran_readiness_employment_claim: { form: no_veteran_info } }

        post(:create, params: form_params)
        expect(response.code).to eq('422')
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
