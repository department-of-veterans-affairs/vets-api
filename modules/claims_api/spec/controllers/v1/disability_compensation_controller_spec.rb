# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V1::Forms::DisabilityCompensationController, type: :controller do
  describe '#format_526_errors' do
    it 'formats errors correctly' do
      error = [
        {
          key: 'header.va_eauth_birlsfilenumber.Invalid',
          severity: 'ERROR',
          text: 'Size must be between 8 and 9'
        }
      ]

      formatted_error = subject.send(:format_526_errors, error)

      expect(formatted_error).to contain_exactly({ status: 422, detail: "#{error[0][:key]}, #{error[0][:text]}",
                                                   source: error[0][:key] })
    end
  end

  describe '#submit_form_526' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:claim_data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end

    let(:claim) { create(:auto_established_claim, form_data: JSON.parse(claim_data)) }

    let(:veteran) do
      OpenStruct.new(
        middle_name: 'William',
        mpi: OpenStruct.new(
          icn: '1012861229V078999'
        )
      )
    end

    let(:token) do
      OpenStruct.new(
        payload: OpenStruct.new(
          cid: '75648392047777685'
        )
      )
    end

    context 'using the PDF Generator' do
      before do
        subject.instance_variable_set(:@json_body, JSON.parse(claim_data)) # mock for form_attributes method calls
        allow_any_instance_of(
          ClaimsApi::RevisedDisabilityCompensationValidations
        ).to receive(:validate_form_526_submission_values!).and_return(nil) # mock passing custom validations
        allow_any_instance_of(
          described_class
        ).to receive(:validate_veteran_identifiers).with(anything).and_return(nil) # valid veteran
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:create).with(any_args).and_return(claim)
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(true)
        allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_async)
        allow(ClaimsApi::AutoEstablishedClaimSerializer).to receive(:new).with(claim).and_return(double(as_json: {}))
        allow_any_instance_of(
          described_class
        ).to receive_messages(validate_json_schema: nil, validate_initial_claim: nil,
                              target_veteran: veteran, token:, auth_headers: {}, render: nil)
      end

      it 'calls the PDF Generator Sidekiq job with the expected params when the flipper is enabled' do
        subject.send(:submit_form_526) # rubocop:disable Naming/VariableNumber

        expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to have_received(:perform_async)
          .with(claim.id, 'W') # 'W' here mimics the method call in the controller to pass just the middle initial
      end
    end
  end
end
