# frozen_string_literal: true

require 'rails_helper'

describe Ccra::BaseService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }

  describe '#config' do
    it 'returns a Ccra::Configuration instance' do
      expect(subject.config).to be_a(Ccra::Configuration)
    end

    it 'memoizes the configuration' do
      config = subject.config
      expect(subject.config).to equal(config)
    end
  end

  describe '#settings' do
    it 'returns the CCRA settings from VAOS configuration' do
      expect(subject.settings).to eq(Settings.vaos.ccra)
    end
  end
end
