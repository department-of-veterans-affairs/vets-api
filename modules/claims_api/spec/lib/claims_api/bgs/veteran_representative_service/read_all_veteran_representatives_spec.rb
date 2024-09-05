# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'veteran_representative_service',
    action: 'read_all_veteran_representatives'
  },
  run_at: '2024-04-17T23:10:31+00:00'
}

describe ClaimsApi::VeteranRepresentativeService, metadata do
  describe '#read_all_veteran_representatives' do
    subject do
      service = described_class.new(**header_params)
      service.read_all_veteran_representatives(**params)
    end

    describe 'with valid external uid and key' do
      let(:header_params) do
        {
          external_uid: 'xUid',
          external_key: 'xKey'
        }
      end

      describe 'with no params' do
        let(:params) { {} }

        it 'raises ArgumentError' do
          use_bgs_cassette('no_params') do
            expect { subject }.to raise_error(ArgumentError)
          end
        end
      end

      describe 'with no type_code param' do
        let(:params) { { ptcpnt_id: '123456' } }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      describe 'with invalid ptcpnt_id param' do
        let(:params) do
          {
            type_code: '21-22',
            ptcpnt_id: '0'
          }
        end

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      describe 'with no ptcpnt_id param' do
        let(:params) { { type_code: '21-22' } }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      describe 'with valid individual params' do
        let(:params) do
          {
            type_code: '21-22A',
            ptcpnt_id: '600043201'
          }
        end

        it 'returns poa requests' do
          use_bgs_cassette('valid_individual') do
            expect(subject.size).to eq(4)
          end
        end
      end

      describe 'with valid org params' do
        let(:params) do
          {
            type_code: '21-22',
            ptcpnt_id: '600043201'
          }
        end

        it 'returns poa requests' do
          use_bgs_cassette('valid_org') do
            expect(subject.size).to eq(6)
          end
        end
      end

      describe 'with a single response' do
        let(:params) do
          {
            type_code: '21-22',
            ptcpnt_id: '600043201'
          }
        end

        it 'handles object vs array' do
          use_bgs_cassette('valid_org_single') do
            expect(subject.size).to eq(1)
          end
        end
      end

      describe 'with an empty response' do
        let(:params) do
          {
            type_code: '21-22',
            ptcpnt_id: '1'
          }
        end

        it 'returns an empty array' do
          use_bgs_cassette('empty_response') do
            expect(subject.size).to eq(0)
          end
        end
      end
    end
  end
end
