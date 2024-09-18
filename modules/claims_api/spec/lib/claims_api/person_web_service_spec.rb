# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/person_web_service'

describe ClaimsApi::PersonWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#find_dependents_by_ptcpnt_id with one dependent' do
    it 'responds as expected' do
      VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
        result = subject.find_dependents_by_ptcpnt_id(600052699) # rubocop:disable Style/NumericLiterals
        expect(result).to be_a Hash
        expect(result[:dependent][:first_nm]).to eq 'MARGIE'
        expect(result[:number_of_records]).to eq '1'
      end
    end
  end

  describe '#find_dependents_by_ptcpnt_id with two dependents' do
    it 'responds as expected' do
      VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
        result = subject.find_dependents_by_ptcpnt_id(600049324) # rubocop:disable Style/NumericLiterals
        expect(result).to be_a Hash
        expect(result[:dependent].size).to eq 2
        expect(result[:dependent].first[:first_nm]).to eq 'MARK'
        expect(result[:number_of_records]).to eq '2'
      end
    end
  end

  describe '#find_dependents_by_ptcpnt_id with no dependents' do
    it 'responds as expected' do
      VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_no_dependents') do
        result = subject.find_dependents_by_ptcpnt_id(123)
        expect(result).to be_a Hash
        expect(result[:number_of_records]).to eq '0'
      end
    end
  end
end
