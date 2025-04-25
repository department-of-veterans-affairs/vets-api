# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::CreateRequest do
  subject { described_class.new(veteran_participant_id, form_data, claimant_participant_id) }

  let(:veteran_participant_id) { '600043284' }

  describe '#call' do
    let(:form_data) do
      temp = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                        'power_of_attorney', 'request_representative', 'valid.json').read)
      temp = temp.deep_symbolize_keys
      temp[:data][:attributes]
    end
    # these get merged in in the request_controller to the form data
    let(:additional_vet_details) do
      {
        firstName: 'Bob',
        lastName: 'Rep',
        ssn: '867530999',
        birthdate: '1965-07-15T08:00:00Z'
      }
    end
    # these get merged in in the request_controller to the form data
    let(:additional_claimant_details) do
      {
        firstName: 'Mary',
        lastName: 'Ellis',
        ssn: '867530222',
        birthdate: '1965-08-15T08:00:00Z'
      }
    end

    context 'when there is a claimant' do
      let(:claimant_participant_id) { '600036513' }

      it 'sets the claimantPtcpntId to the claimant_ptcpnt_id' do
        temp = form_data
        temp[:veteran].merge!(additional_vet_details)
        temp[:claimant].merge!(additional_claimant_details)
        file_name = 'claims_api/power_of_attorney_request_service/create_request/with_claimant'

        VCR.use_cassette(file_name) do
          response = subject.call

          expect(response['claimantPtcpntId']).to eq('188864')
        end
      end

      it 'creates the veteranrepresentative object' do
        file_name = 'claims_api/power_of_attorney_request_service/create_request/with_claimant'
        VCR.use_cassette(file_name) do
          expected_response = {
            'addressLine1' => '2719 Hyperion Ave',
            'addressLine2' => 'Apt 2',
            'addressLine3' => nil,
            'changeAddressAuth' => 'true',
            'city' => 'Los Angeles',
            'claimantPtcpntId' => '188864',
            'claimantRelationship' => 'Spouse',
            'formTypeCode' => '21-22 ',
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
            'procId' => '3860099',
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
            'veteranPtcpntId' => '188863',
            'acceptedBy' => nil,
            'claimantFirstName' => 'MARY',
            'claimantLastName' => 'ELLIS',
            'claimantMiddleName' => nil,
            'declinedBy' => nil,
            'declinedReason' => nil,
            'secondaryStatus' => 'New',
            'veteranFirstName' => 'BOB',
            'veteranLastName' => 'REP',
            'veteranMiddleName' => nil,
            'veteranSSN' => '867530999',
            'veteranVAFileNumber' => nil,
            'meta' => {
              'veteran' => {
                'vnp_mail_id' => '151070',
                'vnp_email_id' => '151071',
                'vnp_phone_id' => '107777'
              },
              'claimant' => {
                'vnp_mail_id' => '151072',
                'vnp_email_id' => '151052',
                'vnp_phone_id' => '107778'
              }
            }
          }

          response = subject.call

          expect(response['meta']).to include(expected_response['meta'])
          expect(response.except('meta')).to match(expected_response.except('meta'))
        end
      end
    end

    context 'when there is not a claimant' do
      let(:claimant_participant_id) { nil }

      it 'sets the claimantPtcpntId to the veteran_ptcpnt_id' do
        temp = form_data
        temp[:claimant] = nil
        temp[:veteran].merge!(additional_vet_details)

        file_name = 'claims_api/power_of_attorney_request_service/create_request/without_claimant'
        VCR.use_cassette(file_name) do
          response = subject.call

          expect(response['claimantPtcpntId']).to eq('188854')
        end
      end

      it 'creates the veteranrepresentative object' do
        file_name = 'claims_api/power_of_attorney_request_service/create_request/without_claimant'
        VCR.use_cassette(file_name) do
          expected_response = {
            'addressLine1' => '2719 Hyperion Ave',
            'addressLine2' => 'Apt 2',
            'addressLine3' => nil,
            'changeAddressAuth' => 'true',
            'city' => 'Los Angeles',
            'claimantPtcpntId' => '188854',
            'claimantRelationship' => nil,
            'formTypeCode' => '21-22 ',
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
            'procId' => '3860074',
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
            'veteranPtcpntId' => '188854',
            'acceptedBy' => nil,
            'claimantFirstName' => 'BOB',
            'claimantLastName' => 'REP',
            'claimantMiddleName' => nil,
            'declinedBy' => nil,
            'declinedReason' => nil,
            'secondaryStatus' => 'New',
            'veteranFirstName' => 'BOB',
            'veteranLastName' => 'REP',
            'veteranMiddleName' => nil,
            'veteranSSN' => '867530999',
            'veteranVAFileNumber' => nil,
            'meta' => {
              'veteran' => {
                'vnp_mail_id' => '150999',
                'vnp_email_id' => '151000',
                'vnp_phone_id' => '107813'
              }
            }
          }

          response = subject.call

          expect(response['meta']).to include(expected_response['meta'])
          expect(response['meta']['veteran']['vnp_mail_id']).to include(
            expected_response['meta']['veteran']['vnp_mail_id']
          )
          expect(response['meta']['veteran']['vnp_email_id']).to include(
            expected_response['meta']['veteran']['vnp_email_id']
          )
          expect(response['meta']['veteran']['vnp_phone_id']).to include(
            expected_response['meta']['veteran']['vnp_phone_id']
          )
        end
      end
    end

    context 'when a person does not have an email' do
      let(:claimant_participant_id) { nil }

      it 'does not attempt to create a vnp email' do
        temp = form_data
        temp[:claimant] = nil
        temp[:veteran].merge!(additional_vet_details)
        temp[:veteran][:email] = nil
        file_name = 'claims_api/power_of_attorney_request_service/create_request/no_email'

        VCR.use_cassette(file_name) do
          receive_count = 0
          allow_any_instance_of(ClaimsApi::VnpPtcpntAddrsService).to receive(:vnp_ptcpnt_addrs_create) do
            receive_count += 1
            nil
          end

          subject.call

          expect(receive_count).to eq(1) # 1 call for the mailing address
        end
      end
    end

    context 'when a person does not have a phone' do
      let(:claimant_participant_id) { nil }

      it 'does not attempt to create a vnp phone' do
        temp = form_data
        temp[:claimant] = nil
        temp[:veteran].merge!(additional_vet_details)
        temp[:veteran][:phone] = nil
        file_name = 'claims_api/power_of_attorney_request_service/create_request/no_phone'

        VCR.use_cassette(file_name) do
          receive_count = 0
          allow_any_instance_of(ClaimsApi::VnpPtcpntPhoneService).to receive(:vnp_ptcpnt_phone_create) {
            receive_count += 1
          }

          subject.call

          expect(receive_count).to eq(0)
        end
      end
    end

    describe '#add_meta_ids' do
      let(:response_obj) do
        {
          'addressLine1' => '2719 Hyperion Ave',
          'addressLine2' => nil,
          'addressLine3' => nil,
          'changeAddressAuth' => 'true',
          'city' => 'Los Angeles',
          'claimantPtcpntId' => '182767',
          'claimantRelationship' => 'Spouse',
          'formTypeCode' => '21-22 ',
          'insuranceNumbers' => nil,
          'limitationAlcohol' => 'false',
          'limitationDrugAbuse' => 'true',
          'limitationHIV' => 'false',
          'limitationSCA' => 'true',
          'organizationName' => 'American Legion',
          'otherServiceBranch' => nil,
          'phoneNumber' => '5555551234',
          'poaCode' => '074',
          'postalCode' => '92264',
          'procId' => '3855183',
          'representativeFirstName' => 'Bob',
          'representativeLastName' => 'GoodRep',
          'representativeLawFirmOrAgencyName' => nil,
          'representativeTitle' => nil,
          'representativeType' => 'Recognized Veterans Service Organization',
          'section7332Auth' => 'true',
          'serviceBranch' => 'Air Force',
          'serviceNumber' => nil,
          'state' => 'CA',
          'vdcStatus' => 'Submitted',
          'veteranPtcpntId' => '182766',
          'acceptedBy' => nil,
          'claimantFirstName' => 'LILLIAN',
          'claimantLastName' => 'DISNEY',
          'claimantMiddleName' => nil,
          'declinedBy' => nil,
          'declinedReason' => nil,
          'secondaryStatus' => nil,
          'veteranFirstName' => 'VERNON',
          'veteranLastName' => 'WAGNER',
          'veteranMiddleName' => nil,
          'veteranSSN' => '796140369',
          'veteranVAFileNumber' => nil
        }
      end

      let(:claimant_participant_id) { nil }

      let(:form_data) do
        {
          veteran: {
            firstName: 'Vernon',
            lastName: 'Wagner',
            serviceBranch: 'Air Force',
            birthdate: '1965-07-15T08:00:00Z',
            ssn: '796140369',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'USA',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551234'
            },
            email: 'test@example.com'
          },
          serviceOrganization: {
            poaCode: '074',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'USA',
              zipCode: '92264'
            },
            organizationName: 'American Legion',
            firstName: 'Bob',
            lastName: 'GoodRep'
          },
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: %w[DRUG_ABUSE SICKLE_CELL]
        }
      end

      let(:expected_res) do
        {
          'meta' => {
            'veteran' => {
              'vnp_mail_id' => '144757',
              'vnp_email_id' => '144758',
              'vnp_phone_id' => '102313'
            },
            'claimant' => {
              'vnp_mail_id' => '144759',
              'vnp_email_id' => '144744',
              'vnp_phone_id' => '102314'
            }
          }
        }
      end

      let(:vet_res_with_nil) do
        {
          'meta' => {
            'veteran' => {
              'vnp_mail_id' => '144757',
              'vnp_email_id' => nil,
              'vnp_phone_id' => '102313'
            }
          }
        }
      end

      let(:claimant_res_with_nil) do
        {
          'meta' => {
            'veteran' => {
              'vnp_mail_id' => '144757',
              'vnp_email_id' => '144758',
              'vnp_phone_id' => nil
            },
            'claimant' => {
              'vnp_mail_id' => nil,
              'vnp_email_id' => '144744',
              'vnp_phone_id' => nil
            }
          }
        }
      end

      it 'adds the ids to the meta' do
        subject.instance_variable_set(:@vnp_res_object, expected_res)

        res = subject.send(:add_meta_ids, response_obj)
        expect(res['meta']).to eq(expected_res['meta'])
      end

      context 'does not add a key that is nil' do
        it 'veteran object is present' do
          subject.instance_variable_set(:@vnp_res_object, vet_res_with_nil)

          res = subject.send(:add_meta_ids, response_obj)
          expect(res['meta']['veteran']).not_to have_key('vnp_email_id')
        end

        it 'veteran and claimant objects are present' do
          subject.instance_variable_set(:@vnp_res_object, claimant_res_with_nil)

          res = subject.send(:add_meta_ids, response_obj)
          expect(res['meta']['veteran']).not_to have_key('vnp_phone_id')
          expect(res['meta']['claimant']).not_to have_key('vnp_mail_id')
          expect(res['meta']['claimant']).not_to have_key('vnp_phone_id')
        end
      end

      it 'does not add a meta key if no IDs are present' do
        subject.instance_variable_set(:@vnp_res_object, { 'meta' => {} })

        res = subject.send(:add_meta_ids, response_obj)
        expect(res).not_to have_key('meta')
      end
    end
  end
end
