# frozen_string_literal: true

require 'rails_helper'

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
      FactoryBot.create(:power_of_attorney,
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
      described_class.new.perform(poa.id)

      poa.reload
      expect(poa.status).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end
  end
end
