# frozen_string_literal: true

require 'rails_helper'
require 'chip/configuration'

describe Chip::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(Chip::Configuration.instance.service_name).to eq('Chip')
    end
  end

  describe '#server_url' do
    it 'has a server url' do
      expect(Chip::Configuration.instance.server_url).to eq("#{Settings.chip.url}/#{Settings.chip.base_path}")
    end
  end

  describe '#api_user' do
    it 'has a api user' do
      expect(Chip::Configuration.instance.api_user).to eq(Settings.chip.tmp_api_user)
    end
  end

  describe '#api_id' do
    it 'has a api id' do
      expect(Chip::Configuration.instance.api_id).to eq(Settings.chip.tmp_api_id)
    end
  end

  describe '#api_username' do
    it 'has a api username' do
      expect(Chip::Configuration.instance.api_username).to eq(Settings.chip.tmp_api_username)
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(Chip::Configuration.instance.connection).to be_an_instance_of(Faraday::Connection)
    end
  end
end
