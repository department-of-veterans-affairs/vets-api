# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'manage_representative_service',
    action: 'read_poa_request'
  }
}

describe ClaimsApi::ManageRepresentativeService, metadata do
  describe '#read_poa_request' do
    subject do
      service = described_class.new(**header_params)
      service.read_poa_request(**params)
    end

    describe 'with invalid external uid and key' do
      let(:header_params) do
        {
          external_uid: 'invalidUid',
          external_key: 'invalidKey'
        }
      end

      let(:params) do
        {
          poa_codes: ['091'],
          statuses: ['new']
        }
      end

      it 'does not seem to care' do
        use_bgs_cassette('invalid_external_uid_and_key') do
          expect(subject).to be_a(Hash)
        end
      end
    end

    describe 'with valid external uid and key' do
      let(:header_params) do
        {
          external_uid: 'xUid',
          external_key: 'xKey'
        }
      end

      describe 'with no params' do
        let(:params) do
          {}
        end

        it 'raises Common::Exceptions::ServiceError' do
          use_bgs_cassette('no_params') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end

      describe 'with no statuses param' do
        let(:params) do
          {
            poa_codes: ['1']
          }
        end

        it 'raises Common::Exceptions::ServiceError' do
          use_bgs_cassette('no_statuses') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end

      describe 'with invalid status in statuses param' do
        let(:params) do
          {
            poa_codes: ['1'],
            statuses: %w[invalid new]
          }
        end

        it 'raises Common::Exceptions::ServiceError' do
          use_bgs_cassette('invalid_status') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end

      describe 'with no poa_codes param' do
        let(:params) do
          {
            statuses: ['new']
          }
        end

        it 'raises Common::Exceptions::ServiceError' do
          use_bgs_cassette('no_poa_codes') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end

      describe 'with nonexistent poa_code param' do
        let(:params) do
          {
            poa_codes: ['1'],
            statuses: ['new']
          }
        end

        it 'raises Common::Exceptions::ServiceError' do
          use_bgs_cassette('nonexistent_poa_code') do
            expect { subject }.to raise_error(
              Common::Exceptions::ServiceError
            )
          end
        end
      end

      describe 'with existent poa_code param' do
        let(:params) do
          {
            poa_codes: ['091'],
            statuses: ['new']
          }
        end

        let(:expected) do
          {
            'poaRequestRespondReturnVOList' => {
              'VSOUserEmail' => nil,
              'VSOUserFirstName' => 'VDC USER',
              'VSOUserLastName' => nil,
              'changeAddressAuth' => 'Y',
              'claimantCity' => 'SEASIDE',
              'claimantCountry' => 'USA',
              'claimantMilitaryPO' => nil,
              'claimantMilitaryPostalCode' => nil,
              'claimantState' => 'MT',
              'claimantZip' => '95102',
              'dateRequestActioned' => '2015-08-05T11:33:20-05:00',
              'dateRequestReceived' => '2015-08-05T11:33:20-05:00',
              'declinedReason' => nil,
              'healthInfoAuth' => 'N',
              'poaCode' => '091',
              'procID' => '52095',
              'secondaryStatus' => 'New',
              'vetFirstName' => 'Wallace',
              'vetLastName' => 'Webb',
              'vetMiddleName' => 'R',
              'vetPtcpntID' => '600043200'
            },
            'totalNbrOfRecords' => '1'
          }
        end

        it 'returns poa requests' do
          use_bgs_cassette('existent_poa_code') do
            expect(subject).to eq(expected)
          end
        end

        describe 'and nonexistent poa_code param' do
          let(:params) do
            {
              poa_codes: %w[091 1],
              statuses: ['new']
            }
          end

          it 'returns the existent poa requests' do
            use_bgs_cassette('existent_and_nonexistent_poa_code') do
              expect(subject).to eq(expected)
            end
          end
        end
      end
    end
  end
end
