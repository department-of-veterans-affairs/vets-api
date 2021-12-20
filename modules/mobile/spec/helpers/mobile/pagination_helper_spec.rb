# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::PaginationHelper, type: :model do
  describe '.paginate' do
    let(:list) { (1..11).to_a }
    let(:url) { 'http://example.com' }

    it 'returns the requested number of records', :aggregate_failures do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({ page_size: 2 })
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq([1, 2])
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 2, total_pages: 6,
                                               total_entries: 11 })
    end

    it 'returns the expected page number', :aggregate_failures do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({ page_number: 2 })
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq([11])
      expect(meta[:meta][:pagination]).to eq({ current_page: 2, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'implements default page number and page size', :aggregate_failures do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({})
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq((1..10).to_a)
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'sets previous and next links to nil when there are no more pages to navigate to', :aggregate_failures do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({ page_size: 11 })
      _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(meta[:links][:prev]).to be_nil
      expect(meta[:links][:next]).to be_nil
    end

    it 'adds whitelisted optional query params to links and ignores other params' do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({ use_cache: true, dont_use_cache: true })
      _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)
      expected_links = {
        self: "#{url}?useCache=true&page[size]=10&page[number]=1",
        first: "#{url}?useCache=true&page[size]=10&page[number]=1",
        prev: nil,
        next: "#{url}?useCache=true&page[size]=10&page[number]=2",
        last: "#{url}?useCache=true&page[size]=10&page[number]=2"
      }

      expect(meta[:links]).to eq(expected_links)
    end

    it 'adds any provided errors to the meta' do
      params = Mobile::V0::Contracts::GetPaginatedList.new.call({})
      error_message = 'Yeah, you can\'t do that'
      _resources, meta = described_class.paginate(list: list, validated_params: params, url: url, errors: error_message)

      expect(meta[:errors]).to eq(error_message)
    end
  end
end
