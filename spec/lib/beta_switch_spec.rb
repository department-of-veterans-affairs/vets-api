# frozen_string_literal: true

require 'rails_helper'

describe BetaSwitch do
  describe '#beta_enabled?' do
    let(:uuid) { SecureRandom.uuid }
    let(:feature) { 'foo' }

    before do
      extend described_class
      BetaRegistration.create!(user_uuid: uuid, feature: feature)
    end

    it 'should return true if the record exists' do
      expect(beta_enabled?(uuid, feature)).to eq(true)
    end

    it 'should return false if the record doesnt exist' do
      expect(beta_enabled?(uuid, 'foo2')).to eq(false)
    end
  end
end
