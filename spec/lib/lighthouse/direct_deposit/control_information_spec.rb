# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/direct_deposit/control_information'

RSpec.describe Lighthouse::DirectDeposit::ControlInformation do
  let(:info) { described_class.new }

  before do
    info.clear_restrictions
  end

  context 'when clear_restrictions is called' do
    it 'is updatable' do
      expect(info.account_updatable?).to be(true)
    end
  end

  context 'when no restrictions' do
    it 'is updateable' do
      expect(info.account_updatable?).to be(true)
      expect(info.restrictions).to be_empty
    end

    context 'and can_update_direct_deposit is false' do
      it 'is invalid' do
        info.is_edu_claim_available = true
        info.can_update_direct_deposit = false

        expect(info.valid?).to be(false)
        expect(info.errors).to eq(['Has no restrictions. Account should be updatable.'])
      end
    end
  end

  context 'when there is a restriction' do
    it 'is not updateable' do
      info.restrictions.each do |name|
        info.clear_restrictions
        info.send("#{name}=", false)

        expect(info.account_updatable?).to be(false)
        expect(info.restrictions).not_to be_empty
      end
    end

    context 'and can_update_direct_deposit is true' do
      it 'is invalid' do
        info.is_corp_available = true
        info.has_index = false
        info.can_update_direct_deposit = true

        expect(info.valid?).to be(false)
        expect(info.errors).to eq(['Has restrictions. Account should not be updatable.'])
      end
    end
  end

  context 'when is_corp_available is true' do
    it 'is for comp and pen' do
      info.is_corp_available = true
      expect(info.comp_and_pen?).to be(true)
    end
  end

  context 'when is_edu_claim_available is true' do
    it 'is for edu benefits' do
      info.is_edu_claim_available = true
      expect(info.edu_benefits?).to be(true)
    end
  end

  context 'when no benefit type' do
    it 'is invalid' do
      expect(info.valid?).to be(false)
      expect(info.errors).to eq(['Missing benefit type. Must be either CnP or EDU benefits.'])
    end
  end

  context 'benefit type' do
    it 'returns a benefit type of cnp' do
      info.is_corp_available = true
      info.is_edu_claim_available = false
      expect(info.benefit_type).to eq('cnp')
    end

    it 'returns a benefit type of edu' do
      info.is_corp_available = false
      info.is_edu_claim_available = true
      expect(info.benefit_type).to eq('edu')
    end

    it 'returns a benefit type of both' do
      info.is_corp_available = true
      info.is_edu_claim_available = true
      expect(info.benefit_type).to eq('both')
    end

    it 'returns a benefit type of none' do
      info.is_corp_available = false
      info.is_edu_claim_available = false
      expect(info.benefit_type).to eq('none')
    end
  end
end
