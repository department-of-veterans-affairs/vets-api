# frozen_string_literal: true

require 'rails_helper'
require 'vets/environment'

RSpec.describe Vets::Environment do
  let(:environment_value) { nil }

  before do
    allow(ENV).to receive(:[]).with('VSP_ENVIRONMENT').and_return(environment_value)
  end

  describe '.current' do
    context 'when VSP_ENVIRONMENT is not set' do
      let(:environment_value) { nil }

      it 'returns "localhost" as the default value' do
        expect(described_class.current).to eq('localhost')
      end
    end

    context 'when VSP_ENVIRONMENT is set to "development"' do
      let(:environment_value) { 'development' }

      it 'returns "development"' do
        expect(described_class.current).to eq('development')
      end
    end
  end

  describe '.to_s' do
    it 'returns the current environment as a string' do
      allow(ENV).to receive(:[]).with('VSP_ENVIRONMENT').and_return('production')
      expect(described_class.to_s).to eq('production')
    end
  end

  describe '.inspect' do
    it 'returns the current environment as a string (formatted for inspection)' do
      allow(ENV).to receive(:[]).with('VSP_ENVIRONMENT').and_return('staging')
      expect(described_class.inspect).to eq('"staging"')
    end
  end

  describe '.development?' do
    context 'when environment is "development"' do
      let(:environment_value) { 'development' }

      it 'returns true' do
        expect(described_class.development?).to be(true)
      end
    end

    context 'when environment is not "development"' do
      let(:environment_value) { 'production' }

      it 'returns false' do
        expect(described_class.development?).to be(false)
      end
    end
  end

  describe '.production?' do
    context 'when environment is "production"' do
      let(:environment_value) { 'production' }

      it 'returns true' do
        expect(described_class.production?).to be(true)
      end
    end

    context 'when environment is not "production"' do
      let(:environment_value) { 'staging' }

      it 'returns false' do
        expect(described_class.production?).to be(false)
      end
    end
  end

  describe '.staging?' do
    context 'when environment is "staging"' do
      let(:environment_value) { 'staging' }

      it 'returns true' do
        expect(described_class.staging?).to be(true)
      end
    end

    context 'when environment is not "staging"' do
      let(:environment_value) { 'production' }

      it 'returns false' do
        expect(described_class.staging?).to be(false)
      end
    end
  end

  describe '.sandbox?' do
    context 'when environment is "sandbox"' do
      let(:environment_value) { 'sandbox' }

      it 'returns true' do
        expect(described_class.sandbox?).to be(true)
      end
    end

    context 'when environment is not "sandbox"' do
      let(:environment_value) { 'test' }

      it 'returns false' do
        expect(described_class.sandbox?).to be(false)
      end
    end
  end

  describe '.local?' do
    context 'when environment is "localhost"' do
      let(:environment_value) { 'localhost' }

      it 'returns true' do
        expect(described_class.local?).to be(true)
      end
    end

    context 'when environment is "test"' do
      let(:environment_value) { 'test' }

      it 'returns true' do
        expect(described_class.local?).to be(true)
      end
    end

    context 'when environment is not "localhost" or "test"' do
      let(:environment_value) { 'production' }

      it 'returns false' do
        expect(described_class.local?).to be(false)
      end
    end
  end

  describe '.lower?' do
    context 'when environment is "development"' do
      let(:environment_value) { 'development' }

      it 'returns true' do
        expect(described_class.lower?).to be(true)
      end
    end

    context 'when environment is "staging"' do
      let(:environment_value) { 'staging' }

      it 'returns true' do
        expect(described_class.lower?).to be(true)
      end
    end

    context 'when environment is "production"' do
      let(:environment_value) { 'production' }

      it 'returns false' do
        expect(described_class.lower?).to be(false)
      end
    end
  end

  describe '.higher?' do
    context 'when environment is "sandbox"' do
      let(:environment_value) { 'sandbox' }

      it 'returns true' do
        expect(described_class.higher?).to be(true)
      end
    end

    context 'when environment is "production"' do
      let(:environment_value) { 'production' }

      it 'returns true' do
        expect(described_class.higher?).to be(true)
      end
    end

    context 'when environment is "development"' do
      let(:environment_value) { 'development' }

      it 'returns false' do
        expect(described_class.higher?).to be(false)
      end
    end
  end

  describe '.deployed?' do
    context 'when environment is local' do
      let(:environment_value) { 'localhost' }

      it 'returns false' do
        expect(described_class.deployed?).to be(false)
      end
    end

    context 'when environment is deployed' do
      let(:environment_value) { 'production' }

      it 'returns true' do
        expect(described_class.deployed?).to be(true)
      end
    end
  end
end
