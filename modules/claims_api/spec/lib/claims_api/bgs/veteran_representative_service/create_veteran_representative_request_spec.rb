# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

describe ClaimsApi::VeteranRepresentativeService do
  describe '#create_veteran_representative' do
    subject do
      service = described_class.new(external_uid: 'xUid', external_key: 'xKey')
      service.create_veteran_representative(**params)
    end

    describe 'with valid request params' do
      let(:params) do
        {
          form_type_code: '21-22',
          proc_id: '3854909',
          veteran_ptcpnt_id: '182359',
          poa_code: '074',
          section_7332_auth: false,
          limitation_drug_abuse: false,
          limitation_alcohol: false,
          limitation_hiv: false,
          limitation_s_c_a: false,
          limitation_h_i_v: false,
          change_address_auth: true,
          vdc_status: 'Submitted',
          representative_type: 'Recognized Veterans Service Organization',
          claimant_ptcpnt_id: '182358',
          # rubocop:disable Naming/VariableNumber
          address_line_1: '76 Crowther Ave',
          # rubocop:enable Naming/VariableNumber
          city: 'Bridgeport',
          postal_code: '06605',
          state: 'CT',
          submitted_date: '2024-04-22T19:27:37Z'
        }
      end

      let(:expected_response) do
        {
          'addressLine1' => '76 Crowther Ave',
          'addressLine2' => nil,
          'addressLine3' => nil,
          'changeAddressAuth' => 'true',
          'city' => 'Bridgeport',
          'claimantPtcpntId' => '182358',
          'claimantRelationship' => nil,
          'formTypeCode' => '21-22 ',
          'insuranceNumbers' => nil,
          'limitationAlcohol' => 'false',
          'limitationDrugAbuse' => 'false',
          'limitationHIV' => 'false',
          'limitationSCA' => 'false',
          'organizationName' => nil,
          'otherServiceBranch' => nil,
          'phoneNumber' => nil,
          'poaCode' => '074',
          'postalCode' => '06605',
          'procId' => '3854909',
          'representativeFirstName' => nil,
          'representativeLastName' => nil,
          'representativeLawFirmOrAgencyName' => nil,
          'representativeTitle' => nil,
          'representativeType' => 'Recognized Veterans Service Organization',
          'section7332Auth' => 'false',
          'serviceBranch' => nil,
          'serviceNumber' => nil,
          'state' => 'CT',
          'vdcStatus' => 'Submitted',
          'veteranPtcpntId' => '182359',
          'acceptedBy' => nil,
          'claimantFirstName' => 'VERNON',
          'claimantLastName' => 'WAGNER',
          'claimantMiddleName' => nil,
          'declinedBy' => nil,
          'declinedReason' => nil,
          'secondaryStatus' => 'Obsolete',
          'veteranFirstName' => 'VERNON',
          'veteranLastName' => 'WAGNER',
          'veteranMiddleName' => nil,
          'veteranSSN' => nil,
          'veteranVAFileNumber' => nil
        }
      end

      it 'returns a response with expected body' do
        VCR.use_cassette('claims_api/bgs/veteran_representative_service/create_veteran_representative/valid_params') do
          expect(subject).to eq(expected_response)
        end
      end
    end

    describe 'with invalid params' do
      describe 'with the MPI participant ID being used instead of the VNP participant ID' do
        let(:params) do
          {
            form_type_code: '21-22',
            proc_id: '3854909',
            veteran_ptcpnt_id: '600043284',
            poa_code: '074',
            section_7332_auth: false,
            limitation_drug_abuse: false,
            limitation_alcohol: false,
            limitation_hiv: false,
            limitation_s_c_a: false,
            limitation_h_i_v: false,
            change_address_auth: true,
            vdc_status: 'Submitted',
            representative_type: 'Recognized Veterans Service Organization',
            claimant_ptcpnt_id: '182358',
            # rubocop:disable Naming/VariableNumber
            address_line_1: '76 Crowther Ave',
            # rubocop:enable Naming/VariableNumber
            city: 'Bridgeport',
            postal_code: '06605',
            state: 'CT',
            submitted_date: '2024-04-22T19:27:37Z'
          }
        end

        it 'raises Common::Exceptions::ServiceError' do
          VCR.use_cassette('mpi_ptcpnt_id_instead_of_vnp_ptcpnt_id') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end
    end
  end
end
