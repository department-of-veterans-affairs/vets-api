# frozen_string_literal: true

require 'rails_helper'

describe VAOS::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(VAOS::Configuration.instance.service_name).to eq('VAOS')
    end
  end

  describe '#connection' do
    it 'returns a connection' do
      expect(VAOS::Configuration.instance.connection).to_not be_nil
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.appeals.mock is true' do
      before { Settings.vaos.mock = 'true' }
      it 'returns true' do
        expect(VAOS::Configuration.instance.mock_enabled?).to be_truthy
      end
    end

    context 'when Settings.appeals.mock is false' do
      before { Settings.vaos.mock = 'false' }
      it 'returns false' do
        expect(VAOS::Configuration.instance.mock_enabled?).to be_falsey
      end
    end
  end
end
