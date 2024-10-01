# frozen_string_literal: true

require 'rails_helper'

describe SearchGsa::Pagination do
  # raw_body instance data is determined by the VCR cassets in support/vcr_cassettes/search/*
  context 'when page number is 1' do
    subject { described_class.new(raw_body) }

    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 10
          }
      }
    end

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 1)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number is 2' do
    subject { described_class.new(raw_body) }

    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 20
          }
      }
    end

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 2)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number is last page' do
    subject { described_class.new(raw_body) }

    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => nil
          }
      }
    end

    it 'calculates the correct pagination object details', :aggregate_failures do
      expect(subject.object).to include('current_page' => 9)
      expect(subject.object).to include('per_page' => 10)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('total_entries' => 85)
    end
  end

  context 'when page number given is greater than total pages' do
    subject { described_class.new(raw_body) }

    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 85,
            'next_offset' => 1000
          }
      }
    end

    it 'returns the last page of results' do
      expect(subject.object).to include('current_page' => 9)
    end
  end

  context 'when Search.govs total entries exceed the OFFSET_LIMIT to view them' do
    subject { described_class.new(raw_body) }

    let(:raw_body) do
      {
        'web' =>
          {
            'total' => 35_123,
            'next_offset' => 20
          }
      }
    end

    it 'sets total_pages to the maximum viewable number of pages' do
      expect(subject.object['total_pages']).to eq 99
    end

    it 'sets total_entries to the maximum viewable number of entries' do
      expect(subject.object['total_entries']).to eq 999
    end

    context 'when the ENTRIES_PER_PAGE is set to its max of 50' do
      before do
        stub_const('Search::Pagination::ENTRIES_PER_PAGE', 50)
      end

      it 'sets total_pages to the maximum viewable number of pages' do
        expect(subject.object['total_pages']).to eq 19
      end

      it 'sets total_entries to the maximum viewable number of entries' do
        expect(subject.object['total_entries']).to eq 999
      end
    end
  end
end
