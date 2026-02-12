# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsClaims::Providers::IvcChampva::ClaimBuilder do
  describe '.status_for' do
    let(:base_time) { Time.zone.parse('2026-02-11 10:00:00') }

    def record(pega_status:, updated_at:)
      OpenStruct.new(pega_status:, updated_at:)
    end

    it 'maps Processed to vbms' do
      records = [record(pega_status: 'Processed', updated_at: base_time)]

      expect(described_class.status_for(records)).to eq('vbms')
    end

    it 'maps explicit error statuses to error' do
      records = [record(pega_status: 'Submission failed', updated_at: base_time)]

      expect(described_class.status_for(records)).to eq('error')
    end

    it 'maps Not Processed to pending' do
      records = [record(pega_status: 'Not Processed', updated_at: base_time)]

      expect(described_class.status_for(records)).to eq('pending')
    end

    it 'maps nil pega_status to pending' do
      records = [record(pega_status: nil, updated_at: base_time)]

      expect(described_class.status_for(records)).to eq('pending')
    end

    it 'uses the most recently updated record, matching submission-status behavior' do
      records = [
        record(pega_status: 'Processed', updated_at: base_time),
        record(pega_status: nil, updated_at: base_time + 1.minute)
      ]

      expect(described_class.status_for(records)).to eq('pending')
    end
  end
end
