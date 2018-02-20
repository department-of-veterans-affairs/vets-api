# frozen_string_literal: true

require 'rails_helper'

describe EVSS::AWSConfiguration do
  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(described_class.instance.mock_enabled?).to be_in([true, false])
    end
  end

  describe '#ssl_options' do
    it 'uses ssl when in production' do
      allow(described_class.instance).to receive(:cert?).and_return(true)
      allow(described_class.instance).to receive(:client_cert).and_return('fakecert')
      allow(described_class.instance).to receive(:client_key).and_return('fakekey')

      expect(described_class.instance.ssl_options)
        .to eq(ca_file: nil,
               client_key: 'fakekey',
               client_cert: 'fakecert',
               verify: true,
               version: :TLSv1_2)
    end
  end
end
