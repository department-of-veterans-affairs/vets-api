# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::Request do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of Request' do
      expect(subject.build).to be_an_instance_of(HealthQuest::Lighthouse::Request)
    end
  end

  describe '#post' do
    it 'returns a Faraday::Response' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(Faraday::Response.new)

      expect(subject.build.post('', '')).to be_an_instance_of(Faraday::Response)
    end
  end
end
