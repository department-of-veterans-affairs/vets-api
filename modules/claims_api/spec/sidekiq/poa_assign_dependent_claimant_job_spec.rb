# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/standard_data_web_service'

RSpec.describe ClaimsApi::PoaAssignDependentClaimantJob, type: :job do
  let(:poa_id) { '98324hfsdfds-8923-po4r-1111-ghieutj9' }

  let(:claimant_form_data) do
    {
      data: {
        attributes: {
          veteran: {
            address: {
              addressLine1: '123',
              city: 'city',
              stateCode: 'OR',
              country: 'US',
              zipCode: '12345'
            }
          },
          serviceOrganization: {
            poaCode: '083',
            registrationNumber: '999999999999'
          },
          claimant: {
            claimantId: '1013062086V794840',
            address: {
              addressLine1: '123',
              city: 'city',
              stateCode: 'OR',
              country: 'US',
              zipCode: '12345'
            },
            relationship: 'spouse'
          }
        }
      }
    }
  end

  let(:auth_headers) do
    {
      'va_eauth_pid' => '123456789',
      'va_eauth_birlsfilenumber' => '987654321',
      'dependent' => {
        'ssn' => '123-456-7890'
      }
    }
  end

  describe '#perform' do
    let(:poa) do
      create(:power_of_attorney,
             auth_headers: auth_headers,
             form_data: claimant_form_data,
             status: ClaimsApi::PowerOfAttorney::SUBMITTED)
    end

    it "marks the POA status as 'updated'" do
      allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
        .to receive(:assign_poa_to_dependent!).and_return(
          true
        )

      allow_any_instance_of(ClaimsApi::ServiceBase)
        .to receive(:enable_vbms_access?).and_return(
          true
        )

      expect(poa.status).to eq(ClaimsApi::PowerOfAttorney::SUBMITTED)
      described_class.new.perform(poa.id, 'Rep Data')

      poa.reload
      expect(poa.status).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end

    context 'if an error occurs in the service call' do
      let(:error) { StandardError.new('error message') }

      it "does not mark the POA status as 'updated'" do
        allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
          .to receive(:assign_poa_to_dependent!).and_raise(error)

        allow_any_instance_of(described_class).to receive(:handle_error).with(poa, error)

        expect_any_instance_of(described_class).to receive(:handle_error)
        described_class.new.perform(poa.id, 'Rep Data')
      end
    end
  end

  context 'Sending the VA Notify email' do
    before do
      create_mock_lighthouse_service
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return true
    end

    let(:poa) do
      create(:power_of_attorney,
             auth_headers: auth_headers,
             form_data: claimant_form_data,
             status: ClaimsApi::PowerOfAttorney::SUBMITTED)
    end
    let(:header_key) { ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY }

    context 'when the header key and rep are present' do
      it 'sends the vanotify job' do
        poa.auth_headers.merge!({
                                  header_key => 'this_value'
                                })
        poa.save!
        allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService).to receive(:assign_poa_to_dependent!)
          .and_return(nil)
        allow_any_instance_of(ClaimsApi::ServiceBase).to receive(:vanotify?).and_return true
        expect(ClaimsApi::VANotifyAcceptedJob).to receive(:perform_async)

        described_class.new.perform(poa.id, '12345678')
      end
    end

    context 'when the flipper is off' do
      it 'does not send the vanotify job' do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return false
        poa.auth_headers.merge!({
                                  header_key => 'this_value'
                                })
        poa.save!
        allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService).to receive(:assign_poa_to_dependent!)
          .and_return(nil)
        expect(ClaimsApi::VANotifyAcceptedJob).not_to receive(:perform_async)

        described_class.new.perform(poa.id, '12345678')
      end
    end
  end

  def create_mock_lighthouse_service
    allow_any_instance_of(ClaimsApi::StandardDataWebService).to receive(:find_poas)
      .and_return([{ legacy_poa_cd: '002', nm: "MAINE VETERANS' SERVICES", org_type_nm: 'POA State Organization',
                     ptcpnt_id: '46004' }])
  end
end
