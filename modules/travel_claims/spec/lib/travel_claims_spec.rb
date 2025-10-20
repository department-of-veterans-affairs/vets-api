# frozen_string_literal: true

require 'spec_helper'
require 'travel_claims'

RSpec.describe TravelClaims do
  describe 'module' do
    it 'has a version number' do
      expect(TravelClaims::VERSION).not_to be_nil
      expect(TravelClaims::VERSION).to eq('0.1.0')
    end

    it 'is defined' do
      expect(defined?(TravelClaims)).to eq('constant')
    end
  end

  describe 'engine' do
    it 'is a Rails::Engine' do
      expect(TravelClaims::Engine.superclass).to eq(Rails::Engine)
    end

    it 'has isolated namespace' do
      expect(TravelClaims::Engine.isolated?).to be(true)
    end
  end
end
