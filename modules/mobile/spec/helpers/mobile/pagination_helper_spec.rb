# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::PaginationHelper, type: :model, aggregate_failures: true do
  describe '.paginate' do
    let(:list) { (1..11).to_a }

    it 'returns the requested number of records' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({ page_size: 2 })
      resources, meta = described_class.paginate(list:, validated_params: params)

      expect(resources).to eq([1, 2])
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 2, total_pages: 6,
                                               total_entries: 11 })
    end

    it 'returns the expected page number' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({ page_number: 2 })
      resources, meta = described_class.paginate(list:, validated_params: params)

      expect(resources).to eq([11])
      expect(meta[:meta][:pagination]).to eq({ current_page: 2, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'implements default page number and page size when none are provided' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({})
      resources, meta = described_class.paginate(list:, validated_params: params)

      expect(resources).to eq((1..10).to_a)
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'adds any provided errors to the meta' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({})
      error_message = 'Yeah, you can\'t do that'
      _resources, meta = described_class.paginate(list:, validated_params: params, errors: error_message)

      expect(meta[:errors]).to eq(error_message)
    end

    it 'raises an error if the provided validated_params are not a contract object' do
      expect do
        described_class.paginate(list:, validated_params: { page_size: 10, page_number: 1 })
      end.to raise_error(
        Mobile::PaginationHelper::InvalidParams,
        'Params must be a contract result. Use Mobile::V0::Contracts::PaginationBase or subclass.'
      )
    end
  end
end
