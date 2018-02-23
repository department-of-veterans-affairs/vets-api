# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MhvAccountTypeService do
  let(:user_identity) { instance_double('UserIdentity', mhv_account_type: nil) }
  let(:user) { instance_double('User', mhv_correlation_id: '12210827', identity: user_identity) }
  subject { described_class.new(user) }

  context 'no mhv_correlation_id' do
    let(:user) { instance_double('User', mhv_correlation_id: nil) }

    it '#probable_account_type returns nil' do
      expect(subject).not_to receive(:log_account_type_heuristic_once)
      expect(subject.probable_account_type).to be_nil
    end
  end

  context 'known mhv_account_type' do
    let(:user_identity) { instance_double('UserIdentity', mhv_account_type: 'Whatever') }

    it '#probable_account_type returns known account type' do
      expect(subject).to receive(:log_account_type_heuristic_once).with(
        'MHV Account Type Known'
      )
      expect(subject.probable_account_type).to eq('Whatever')
    end
  end

  context 'premium user' do
    it '#probable_account_type returns Premium' do
      VCR.use_cassette('mhv_account_type_service/premium') do
        eligible_data_classes = subject.eligible_data_classes
        expect(subject).to receive(:log_account_type_heuristic_once).with(
          'MHV Account Type Unknown'
        )
        expect(eligible_data_classes.count).to eq(32)
        expect(subject.probable_account_type).to eq('Premium')
      end
    end
  end

  context 'advanced user' do
    it '#probable_account_type returns Advanced' do
      VCR.use_cassette('mhv_account_type_service/advanced') do
        eligible_data_classes = subject.eligible_data_classes
        expect(subject).to receive(:log_account_type_heuristic_once).with(
          'MHV Account Type Unknown'
        )
        expect(eligible_data_classes.count).to eq(18)
        expect(subject.probable_account_type).to eq('Advanced')
      end
    end
  end

  context 'basic user' do
    it '#probable_account_type returns Basic' do
      VCR.use_cassette('mhv_account_type_service/basic') do
        eligible_data_classes = subject.eligible_data_classes
        expect(subject).to receive(:log_account_type_heuristic_once).with(
          'MHV Account Type Unknown'
        )
        expect(eligible_data_classes.count).to eq(8)
        expect(subject.probable_account_type).to eq('Basic')
      end
    end
  end
end
