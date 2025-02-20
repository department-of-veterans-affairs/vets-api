# frozen_string_literal: true

require 'rails_helper'
require 'vets/collections/pagination'
require 'common/exceptions/invalid_pagination_params'

RSpec.describe Vets::Collections::Pagination do
  let(:data) { (1..50).to_a } # Example data

  describe '#initialize' do
    context 'without WillPaginate' do
      it 'paginates the data correctly' do
        pagination = described_class.new(page: 2, per_page: 10, total_entries: data.size, data:)
        expect(pagination.data).to eq((11..20).to_a)
      end

      it 'returns an empty array for out-of-bounds page' do
        pagination = described_class.new(page: 6, per_page: 10, total_entries: data.size, data:)
        expect(pagination.data).to eq([])
      end

      context 'when data is nil' do
        it 'returns an empty array and total_pages is 1' do
          pagination = described_class.new(page: 6, per_page: 10, total_entries: nil, data: nil)
          expect(pagination.data).to eq([])
          expect(pagination.metadata[:pagination][:total_pages]).to eq(1)
        end
      end
    end

    context 'with WillPaginate' do
      before do
        allow(WillPaginate::Collection).to receive(:create).and_call_original
      end

      it 'uses WillPaginate::Collection for pagination' do
        described_class.new(page: 1, per_page: 10, total_entries: data.size, data:,
                            use_will_paginate: true)
        expect(WillPaginate::Collection).to have_received(:create).with(1, 10, data.size)
      end

      it 'raises an exception for invalid pagination params' do
        allow_any_instance_of(WillPaginate::Collection).to receive(:out_of_bounds?).and_return(true)

        expect do
          described_class.new(page: 10, per_page: 10, total_entries: data.size, data:, use_will_paginate: true)
        end.to raise_error(Common::Exceptions::InvalidPaginationParams)
      end
    end
  end

  describe '#metadata' do
    it 'returns the correct pagination metadata' do
      pagination = described_class.new(page: 2, per_page: 10, total_entries: data.size, data:)
      expected_metadata = {
        pagination: {
          current_page: 2,
          per_page: 10,
          total_pages: 5,
          total_entries: 50
        }
      }

      expect(pagination.metadata).to eq(expected_metadata)
    end
  end
end
