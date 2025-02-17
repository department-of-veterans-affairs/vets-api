# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/person_web_service'
require 'bd/bd'

describe ClaimsApi::PersonWebService do
  subject do
    described_class.new external_uid: 'xUid', external_key: 'xKey'
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe '#find_dependents_by_ptcpnt_id' do
    context 'with a participant that has one dependent' do
      it 'responds with one dependent' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          result = subject.find_dependents_by_ptcpnt_id('600052699')
          expect(result).to be_a Hash
          expect(result[:dependent][:first_nm]).to eq 'MARGIE'
          expect(result[:number_of_records]).to eq '1'
        end
      end
    end

    context 'with a participant that has two dependents' do
      it 'responds with two dependents' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          # integers should work too
          result = subject.find_dependents_by_ptcpnt_id(600049324) # rubocop:disable Style/NumericLiterals
          expect(result).to be_a Hash
          expect(result[:dependent]).to be_an Array
          expect(result[:dependent].size).to eq 2
          expect(result[:dependent].first[:first_nm]).to eq 'MARK'
          expect(result[:number_of_records]).to eq '2'
        end
      end
    end

    context 'with a participant that has no dependents' do
      it 'responds as expected' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_no_dependents') do
          result = subject.find_dependents_by_ptcpnt_id(123)
          expect(result).to be_a Hash
          expect(result[:number_of_records]).to eq '0'
        end
      end
    end
  end

  describe '#manage_ptcpnt_rlnshp_poa' do
    context 'when participant A (the veteran or dependent) has no open claims' do
      let(:ptcpnt_id_a) { '601163580' }
      let(:ptcpnt_id_b) { '46004' }

      it 'assigns the POA to the participant' do
        VCR.use_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_no_open_claims') do
          options = {
            ptcpnt_id_a:,
            ptcpnt_id_b:
          }
          result = subject.manage_ptcpnt_rlnshp_poa(options:)

          expect(result).to be_a Hash
          expect(result[:comp_id][:ptcpnt_id_a]).to eq ptcpnt_id_a
          expect(result[:comp_id][:ptcpnt_id_b]).to eq ptcpnt_id_b
          expect(result[:comp_id][:ptcpnt_rlnshp_type_nm]).to eq 'Power of Attorney For'
        end
      end
    end

    context 'when participant A (the veteran or dependent) has open claims' do
      it 'returns an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_with_open_claims') do
          options = {
            ptcpnt_id_a: '600052700',
            ptcpnt_id_b: '46004'
          }

          expect do
            subject.manage_ptcpnt_rlnshp_poa(options:)
          end.to raise_error(Common::Exceptions::ServiceError) { |error|
                   expect(error.errors.first.detail).to eq 'PtcpntIdA has open claims.'
                 }
        end
      end
    end
  end
end
