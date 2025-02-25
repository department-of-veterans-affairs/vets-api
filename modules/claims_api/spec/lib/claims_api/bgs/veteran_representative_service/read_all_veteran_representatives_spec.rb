# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

describe ClaimsApi::VeteranRepresentativeService do
  describe '#read_all_veteran_representatives' do
    subject do
      service = described_class.new external_uid: 'xUid', external_key: 'xKey'
      service.read_all_veteran_representatives(**params)
    end

    describe 'with no params' do
      let(:params) { {} }

      it 'raises ArgumentError' do
        VCR.use_cassette('no_params') do
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
        VCR.use_cassette(
          'claims_api/bgs/veteran_representative_service/read_all_veteran_representatives/valid_individual'
        ) do
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
        VCR.use_cassette(
          'claims_api/bgs/veteran_representative_service/read_all_veteran_representatives/valid_org'
        ) do
          expect(subject.size).to eq(6)
        end
      end
    end
  end
end
