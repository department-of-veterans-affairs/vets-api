# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Facilities::Request do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of Request' do
      expect(subject.build).to be_an_instance_of(HealthQuest::Facilities::Request)
    end
  end

  describe '#get' do
    let(:query_params) { 'vha_442' }
    let(:json_string) { { data: [{ id: 'vha_442', type: 'facility', attributes: '' }] }.to_json }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(Faraday::Connection).to receive(:get)
        .with('/facilities_api/v1/va').and_return(Faraday::Response.new)
      allow_any_instance_of(Faraday::Response).to receive(:body).and_return(json_string)

      expect(subject.build.get(query_params)).to eq(JSON.parse(json_string)['data'])
    end
  end

  describe '#facilities_headers' do
    it 'returns a Faraday::Response' do
      expect(subject.build.facilities_headers).to eq({ 'Source-App-Name' => 'healthcare_experience_questionnaire' })
    end
  end
end
