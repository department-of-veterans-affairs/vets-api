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

  it 'sets retry_for to 48 hours' do
    expect(described_class.get_sidekiq_options['retry_for']).to eq(48.hours)
  end

  describe '#perform' do
    let(:poa) do
      create(:power_of_attorney,
             auth_headers:,
             form_data: claimant_form_data,
             status: ClaimsApi::PowerOfAttorney::SUBMITTED)
    end

    it 'logs out the details correctly for consent information' do
      poa_code = poa.form_data['data']['attributes']['serviceOrganization']['poaCode']
      consent_msg = 'Updating Access. recordConsent: false ' \
                    "for representative #{poa_code}"

      allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
        .to receive(:assign_poa_to_dependent!).and_return(
          true
        )

      detail_msg = ClaimsApi::ServiceBase.new.send(:form_logger_consent_detail, poa, poa_code)

      expect(detail_msg).to eq(consent_msg)
      described_class.new.perform(poa.id, 'Rep Data')
    end

    it "marks the POA status as 'updated'" do
      allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
        .to receive(:assign_poa_to_dependent!).and_return(
          true
        )

      allow_any_instance_of(ClaimsApi::ServiceBase)
        .to receive(:allow_poa_access?).and_return(
          true
        )

      expect(poa.status).to eq(ClaimsApi::PowerOfAttorney::SUBMITTED)
      described_class.new.perform(poa.id, 'Rep Data')

      poa.reload
      expect(poa.status).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end

    describe 'allow_poa_access' do
      let(:dependent_claimant_poa_assignment_service) do
        instance_double(ClaimsApi::DependentClaimantPoaAssignmentService)
      end

      before do
        allow(ClaimsApi::DependentClaimantPoaAssignmentService).to receive(:new)
          .and_return(dependent_claimant_poa_assignment_service)
        allow(dependent_claimant_poa_assignment_service).to receive(:assign_poa_to_dependent!).and_return(nil)
      end

      context 'when recordConsent is true and consentLimits are blank' do
        before do
          poa.form_data['recordConsent'] = true
          poa.form_data['consentLimits'] = []
          poa.save
        end

        it "sets allow_poa_access to 'Y'" do
          expect(ClaimsApi::DependentClaimantPoaAssignmentService)
            .to receive(:new)
            .with(hash_including(allow_poa_access: 'Y'))

          described_class.new.perform(poa.id)
        end
      end

      context 'when recordConsent is false' do
        before do
          poa.form_data['recordConsent'] = false
          poa.save
        end

        it "sets allow_poa_access to 'N'" do
          expect(ClaimsApi::DependentClaimantPoaAssignmentService)
            .to receive(:new)
            .with(hash_including(allow_poa_access: 'N'))

          described_class.new.perform(poa.id)
        end
      end

      context 'when recordConsent is true but consentLimits are present' do
        before do
          poa.form_data['recordConsent'] = true
          poa.form_data['consentLimits'] = %w[consentLimit1 consentLimit2]
          poa.save
        end

        it "sets allow_poa_access to 'N'" do
          expect(ClaimsApi::DependentClaimantPoaAssignmentService)
            .to receive(:new)
            .with(hash_including(allow_poa_access: 'N'))

          described_class.new.perform(poa.id)
        end
      end

      context 'when recordConsent is missing' do
        before do
          poa.form_data.delete('recordConsent')
          poa.form_data['consentLimits'] = []
          poa.save
        end

        it "sets allow_poa_access to 'N'" do
          expect(ClaimsApi::DependentClaimantPoaAssignmentService)
            .to receive(:new)
            .with(hash_including(allow_poa_access: 'N'))

          described_class.new.perform(poa.id)
        end
      end
    end

    context 'if an error occurs in the service call' do
      let(:error) { StandardError.new('error message') }

      it "calls #handle_error to handle marking the POA's errored state" do
        allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
          .to receive(:assign_poa_to_dependent!).and_raise(error)

        allow_any_instance_of(described_class).to receive(:handle_error).with(poa, error)

        expect_any_instance_of(described_class).to receive(:handle_error)
        expect(poa).not_to receive(:save)
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
             auth_headers:,
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
