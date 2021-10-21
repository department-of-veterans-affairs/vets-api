# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::LighthouseSession, type: :model do
  context 'with valid attributes' do
    let(:session) { Mobile::V0::LighthouseSession.new(access_token: 'abc123', expires_in: 300) }

    it 'has an access_token attribute' do
      expect(session.access_token).to eq('abc123')
    end

    it 'has an expires_in attribute' do
      expect(session.expires_in).to eq(300)
    end
  end

  context 'with invalid attributes' do
    it 'raises a struct error' do
      expect do
        Mobile::V0::LighthouseSession.new(access_token: 'abc123', expires_in: 'two seconds')
      end.to raise_error(Dry::Struct::Error)
    end
  end
end
