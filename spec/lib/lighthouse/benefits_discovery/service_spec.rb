# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'

RSpec.describe BenefitsDiscovery::Service do
  subject { BenefitsDiscovery::Service.new }

  context 'without params' do
    it 'good question; what will this do?' do
      response = subject.get_eligible_benefits
      expect(response).to eq(?)
    end
  end

  context 'with params' do
    it 'responds successfully' do
      response = subject.get_eligible_benefits
      expect(response).to eq(?)
    end
  end
end
