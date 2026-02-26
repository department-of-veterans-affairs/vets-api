# frozen_string_literal: true

require 'rails_helper'
require 'education_benefits_claims/monitor'

RSpec.describe EducationBenefitsClaims::Monitor do
  let(:claim) { create(:va0989) }
  let(:monitor) { described_class.new(claim) }

  describe '#service_name' do
    it 'returns expected name' do
      expect(monitor.send(:service_name)).to eq('education-benefits')
    end
  end

  describe '#claim_stats_key' do
    it 'returns expected value' do
      expect(monitor.send(:claim_stats_key)).to eq('api.education_benefits')
    end
  end

  describe '#submission_stats_key' do
    it 'returns expected value' do
      expect(monitor.send(:submission_stats_key)).to eq('app.education_benefits.submit_benefits_intake_claim')
    end
  end

  describe '#form_id' do
    it 'returns expected value' do
      expect(monitor.send(:form_id)).to eq('22-0989')
    end
  end
end
