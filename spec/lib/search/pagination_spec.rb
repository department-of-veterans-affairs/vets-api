# frozen_string_literal: true

require 'rails_helper'

describe Search::Pagination do
  context 'when page number is 1' do
    let(:raw_body) do
      {
        'total' => 85,
        'next_offset' => 10
      }
    end
    subject { described_class.new(raw_body) }

    it 'calculates the correct pagination object details' do
      expect(subject.object).to include('current_page' => 1)
      expect(subject.object).to include('total_pages' => 9)
      expect(subject.object).to include('results_per_page' => Search::Pagination::RESULTS_PER_PAGE)
    end
  end

  context 'when page number given is greater than total pages' do
    let(:raw_body) do
      {
        'total' => 85
      }
    end
    subject { described_class.new(raw_body) }

    it 'returns the last page of results' do
      expect(subject.object).to include('current_page' => 9)
    end
  end
end
