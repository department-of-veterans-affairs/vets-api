# frozen_string_literal: true

require 'rails_helper'

describe VBMS::Efolder::Configuration do
  subject { described_class }

  it 'has a service name' do
    expect(described_class.instance.service_name).to eq('vbms_efolder')
  end

  describe '#mock_enabled?' do
    context 'when Settings.vbms.efolder.mock is true' do
      before { Settings.vbms.efolder.mock = 'true' }

      it 'returns true' do
        expect(described_class.instance).to be_mock_enabled
      end
    end

    context 'when Settings.vbms.efolder.mock is false' do
      before { Settings.vbms.efolder.mock = 'false' }

      it 'returns false' do
        expect(described_class.instance).not_to be_mock_enabled
      end
    end
  end
end
