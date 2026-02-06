# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::Orchestrator do
  subject { described_class.new(veteran_participant_id, form_data, claimant_participant_id) }

  let(:veteran_participant_id) { '600052700' }
  let(:poa_key) { :poa }
  let(:claimant_participant_id) { '600052699' }
  let(:form_data) do
    temp = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', 'request_representative',
                                      'valid.json').read)
    attributes = temp['data']['attributes']
    # make this a valid relationship to Margie Curtis's dependent, Jerry Curtis
    attributes['claimant']['claimantId'] = '1013030865V203693'
    # This data needs to be 'faked' it gets added during the request controller workflow before calling this
    attributes['veteran']['firstName'] = 'Margie'
    attributes['veteran']['lastName'] = 'Curtis'
    attributes['claimant']['firstName'] = 'Jerry'
    attributes['claimant']['lastName'] = 'Curtis'
    temp = temp.deep_symbolize_keys
    temp[:data][:attributes]
  end

  describe '#submit_request' do
    it 'terminates the existing requests' do
      file_name = 'claims_api/power_of_attorney_request_service/orchestrator/happy_path'
      VCR.use_cassette(file_name) do
        expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests)
          .to receive(:call)
          .and_call_original

        subject.submit_request
      end
    end

    it 'creates a new request' do
      file_name = 'claims_api/power_of_attorney_request_service/orchestrator/happy_path'
      VCR.use_cassette(file_name) do
        expected_response = {
          'addressLine1' => '2719 Hyperion Ave',
          'addressLine2' => 'Apt 2',
          'addressLine3' => nil,
          'changeAddressAuth' => 'true',
          'city' => 'Los Angeles',
          'claimantPtcpntId' => '189363',
          'claimantRelationship' => 'Spouse',
          'formTypeCode' => '21-22',
          'insuranceNumbers' => '1234567890',
          'limitationAlcohol' => 'true',
          'limitationDrugAbuse' => 'true',
          'limitationHIV' => 'true',
          'limitationSCA' => 'true',
          'organizationName' => nil,
          'otherServiceBranch' => nil,
          'phoneNumber' => '5555551234',
          'poaCode' => '067',
          'postalCode' => '92264',
          'procId' => '3860477',
          'representativeFirstName' => nil,
          'representativeLastName' => nil,
          'representativeLawFirmOrAgencyName' => nil,
          'representativeTitle' => nil,
          'representativeType' => 'Recognized Veterans Service Organization',
          'section7332Auth' => 'true',
          'serviceBranch' => 'Army',
          'serviceNumber' => '123678453',
          'state' => 'CA',
          'vdcStatus' => 'SUBMITTED',
          'veteranPtcpntId' => '189362',
          'acceptedBy' => nil,
          'claimantFirstName' => 'JERRY',
          'claimantLastName' => 'CURTIS',
          'claimantMiddleName' => nil,
          'declinedBy' => nil,
          'declinedReason' => nil,
          'secondaryStatus' => 'New',
          'veteranFirstName' => 'MARGIE',
          'veteranLastName' => 'CURTIS',
          'veteranMiddleName' => nil,
          'veteranSSN' => nil,
          'veteranVAFileNumber' => nil,
          'meta' => {
            'veteran' => {
              'vnp_mail_id' => '151669',
              'vnp_email_id' => '151670',
              'vnp_phone_id' => '108159',
              'phone_data' => {
                'areaCode' => '555',
                'phoneNumber' => '5551234'
              }
            },
            'claimant' => {
              'vnp_mail_id' => '151671',
              'vnp_email_id' => '151672',
              'vnp_phone_id' => '108160',
              'phone_data' => {
                'areaCode' => '555',
                'phoneNumber' => '5559876'
              }
            }
          }
        }

        expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::CreateRequest)
          .to receive(:call)
          .and_call_original
        response = subject.submit_request

        # Meta does not always return in the exact same order
        # Meta values: check presence of expected keys and that IDs/phone data are present
        # Because this runs async the IDs are coming back mixed up occasionally
        # This check should resolve the flakiness that creates
        %w[veteran claimant].each do |person|
          expect(response['meta'][person]).to include(
            'vnp_mail_id' => be_present,
            'vnp_email_id' => be_present,
            'vnp_phone_id' => be_present,
            'phone_data' => include('areaCode' => be_present, 'phoneNumber' => be_present)
          )
        end
        expect(response.except('meta')).to match(expected_response.except('meta'))
      end
    end
  end
end
