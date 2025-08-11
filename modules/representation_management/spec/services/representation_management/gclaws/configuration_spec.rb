# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::GCLAWS::Configuration do
  subject { described_class.new(type:, page:, page_size:) }

  let(:type) { 'agents' }
  let(:page) { 1 }
  let(:page_size) { 10 }

  describe '#connection' do
    it 'creates a Faraday connection' do
      expect(subject.connection).to be_a(Faraday::Connection)
    end

    it 'sets the search params' do
      expect(subject.connection.params).to eq({ 'sortColumn' => 'LastName', 'sortOrder' => 'ASC', 'page' => 1,
                                                'pageSize' => 10 })
    end

    it 'sets the url' do
      expect(subject.connection.url_prefix.to_s).to eq(Settings.gclaws.accreditation.agents.url)
    end

    it 'sets the api_key' do
      expect(subject.connection.headers['x-api-key']).to eq(Settings.gclaws.accreditation.api_key)
    end

    it 'sets the origin' do
      expect(subject.connection.headers['Origin']).to eq(Settings.gclaws.accreditation.origin)
    end
  end
end
