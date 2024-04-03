# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_helpers.rb')

metadata = {
  bgs: {
    service: 'manage_representative_service',
    operation: 'read_poa_request'
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
            poa_request_respond_return_vo_list: {
              vso_user_email: nil,
              vso_user_first_name: 'VDC USER',
              vso_user_last_name: nil,
              change_address_auth: 'Y',
              claimant_city: 'SEASIDE',
              claimant_country: 'USA',
              claimant_military_po: nil,
              claimant_military_postal_code: nil,
              claimant_state: 'MT',
              claimant_zip: '95102',
              date_request_actioned: '2015-08-05T11:33:20-05:00',
              date_request_received: '2015-08-05T11:33:20-05:00',
              declined_reason: nil,
              health_info_auth: 'N',
              poa_code: '091',
              proc_id: '52095',
              secondary_status: 'New',
              vet_first_name: 'Wallace',
              vet_last_name: 'Webb',
              vet_middle_name: 'R',
              vet_ptcpnt_id: '600043200'
            },
            total_nbr_of_records: '1'
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
