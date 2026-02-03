# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::GCLAWS::XlsxConfiguration do
  subject(:configuration) { described_class.new }

  let(:test_url) { 'https://ssrs.example.com/reports/accreditation.xlsx' }
  let(:test_username) { 'test_user' }
  let(:test_password) { 'test_password' }

  before do
    allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
      OpenStruct.new(
        url: test_url,
        username: test_username,
        password: test_password
      )
    )
  end

  describe '#url' do
    it 'returns the configured URL from settings' do
      expect(configuration.url).to eq(test_url)
    end
  end

  describe '#username' do
    it 'returns the configured username from settings' do
      expect(configuration.username).to eq(test_username)
    end
  end

  describe '#password' do
    it 'returns the configured password from settings' do
      expect(configuration.password).to eq(test_password)
    end
  end

  describe '#hostname' do
    it 'extracts the hostname from the URL' do
      expect(configuration.hostname).to eq('ssrs.example.com')
    end

    it 'handles URL with path' do
      allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
        OpenStruct.new(
          url: 'https://server.va.gov/path/to/report.xlsx',
          username: test_username,
          password: test_password
        )
      )

      expect(configuration.hostname).to eq('server.va.gov')
    end

    it 'handles URL with port' do
      allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
        OpenStruct.new(
          url: 'https://ssrs.example.com:8443/reports/accreditation.xlsx',
          username: test_username,
          password: test_password
        )
      )

      expect(configuration.hostname).to eq('ssrs.example.com')
    end
  end
end
