# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VeteranReadinessEmploymentClaimsController, type: :controller do
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
    before do
      allow(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: true) }
    end

    context 'logged in ' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '319' } }
          )
          sign_in_as(loa3_user)

          form_params = { veteran_readiness_employment_claim: { form: test_form.form } }
          expect_any_instance_of(SavedClaim::VeteranReadinessEmploymentClaim).not_to receive(:send_to_central_mail!)

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end
    end

    context 'logged in user with no pid' do
      it 'validates successfully and sends to central mail' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '319' } }
          )
          sign_in_as(user_no_pid)

          form_params = { veteran_readiness_employment_claim: { form: test_form.form } }

          post(:create, params: form_params)
          expect(response.code).to eq('200')
        end
      end
    end

    context 'visitor' do
      it 'validates successfully' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '319' } }
          )
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
