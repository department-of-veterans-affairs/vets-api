# frozen_string_literal: true

require 'rails_helper'

describe Search::Pagination do
  # raw_body instance data is determined by the VCR cassets in support/vcr_cassettes/search/*
  context 'when page number is 1' do
    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 10
          }
      }
    end
    subject { described_class.new(raw_body) }

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 1)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number is 2' do
    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 20
          }
      }
    end
    subject { described_class.new(raw_body) }

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 2)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number is last page' do
    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => nil
          }
      }
    end
    subject { described_class.new(raw_body) }

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 9)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number given is greater than total pages' do
    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 1000
          }
      }
    end
    subject { described_class.new(raw_body) }

    it 'returns the last page of results' do
      expect(subject.object).to include('current_page' => 9)
    end
  end
end
