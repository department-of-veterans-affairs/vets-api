# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/direct_deposit/control_information'

RSpec.describe Lighthouse::DirectDeposit::ControlInformation do
  let(:info) { described_class.new }

  before do
    info.clear_restrictions
  end

  context 'when no restrictions' do
    it 'is updateable' do
      expect(info.account_updatable?).to be(true)
      expect(info.restrictions).to be_empty
    end
  end

  context 'when there is a restriction' do
    it 'is not updateable' do
      Lighthouse::DirectDeposit::ControlInformation::RESTRICTIONS.each do |name|
        info.clear_restrictions
        info.send("#{name}=", false)

        expect(info.account_updatable?).to be(false)
        expect(info.restrictions).not_to be_empty
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

  context 'has no benefit type' do
    it 'is invalid' do
      expect(info.valid?).to be(false)
      expect(info.errors).to eq(['Missing benefit type. Must be either CnP or EDU benefits.'])
    end
  end

  context 'has restrictions' do
    it 'account should not be updatable' do
      info.is_edu_claim_available = true
      info.has_identity = false

      expect(info.valid?).to be(false)
      expect(info.errors).to eq(['Has restrictions. Account should not be updatable.'])
    end
  end

  context 'has no restrictions' do
    it 'account should be updatable' do
      info.is_corp_available = true
      info.can_update_direct_deposit = false

      expect(info.valid?).to be(false)
      expect(info.errors).to eq(['Has no restrictions. Account should be updatable.'])
    end
  end
end
