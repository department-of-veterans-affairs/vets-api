# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::Engine do
  describe 'module structure' do
    it 'defines the DependentsBenefits module' do
      expect(defined?(DependentsBenefits)).to eq('constant')
      expect(DependentsBenefits).to be_a(Module)
    end

    it 'defines the Engine class within DependentsBenefits module' do
      expect(DependentsBenefits.const_defined?(:Engine)).to be true
    end
  end
end
