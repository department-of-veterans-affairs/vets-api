# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::PaginationHelper, type: :model, aggregate_failures: true do
  describe '.paginate' do
    let(:list) { (1..11).to_a }
    let(:url) { 'http://example.com' }

    it 'returns the requested number of records' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({ page_size: 2 })
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq([1, 2])
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 2, total_pages: 6,
                                               total_entries: 11 })
    end

    it 'returns the expected page number' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({ page_number: 2 })
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq([11])
      expect(meta[:meta][:pagination]).to eq({ current_page: 2, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'implements default page number and page size when none are provided' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({})
      resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

      expect(resources).to eq((1..10).to_a)
      expect(meta[:meta][:pagination]).to eq({ current_page: 1, per_page: 10, total_pages: 2,
                                               total_entries: 11 })
    end

    it 'adds any provided errors to the meta' do
      params = Mobile::V0::Contracts::PaginationBase.new.call({})
      error_message = 'Yeah, you can\'t do that'
      _resources, meta = described_class.paginate(list: list, validated_params: params, url: url, errors: error_message)

      expect(meta[:errors]).to eq(error_message)
    end

    it 'raises an error if the provided validated_params are not a contract object' do
      expect do
        described_class.paginate(list: list, validated_params: { page_size: 10, page_number: 1 }, url: url)
      end.to raise_error(
        Mobile::PaginationHelper::InvalidParams,
        'Params must be a contract result. Use Mobile::V0::Contracts::PaginationBase or subclass.'
      )
    end

    it 'raises an error when a param is an contains an empty hash' do
      params = Mobile::V0::Contracts::Prescriptions.new.call({ filter: { uno: {} } })

      expect do
        described_class.paginate(list: list, validated_params: params, url: url)
      end.to raise_error(
        Mobile::PaginationHelper::InvalidParams,
        'Invalid hash -- filter: {:uno=>{}}'
      )
    end

    it 'raises an error when a param is an contains a hash with an empty key' do
      params = Mobile::V0::Contracts::Prescriptions.new.call({ filter: { uno: { dos: '' } } })

      expect do
        described_class.paginate(list: list, validated_params: params, url: url)
      end.to raise_error(
        Mobile::PaginationHelper::InvalidParams,
        'Invalid hash -- filter: {:uno=>{:dos=>""}}'
      )
    end

    describe 'link formation' do
      it 'forms links with page values' do
        params = Mobile::V0::Contracts::PaginationBase.new.call({ page_size: 2, page_number: 2 })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=2&page[number]=2',
                                     first: 'http://example.com?page[size]=2&page[number]=1',
                                     prev: 'http://example.com?page[size]=2&page[number]=1',
                                     next: 'http://example.com?page[size]=2&page[number]=3',
                                     last: 'http://example.com?page[size]=2&page[number]=6'
                                   })
      end

      it 'sets previous and next links to nil when there are no more pages to navigate to' do
        params = Mobile::V0::Contracts::PaginationBase.new.call({ page_size: 11 })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links][:prev]).to be_nil
        expect(meta[:links][:next]).to be_nil
      end

      it 'sets self, first, and last links to the first page when there are no results' do
        params = Mobile::V0::Contracts::PaginationBase.new.call({})
        _resources, meta = described_class.paginate(list: [], validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1',
                                     first: 'http://example.com?page[size]=10&page[number]=1',
                                     prev: nil,
                                     next: nil,
                                     last: 'http://example.com?page[size]=10&page[number]=1'
                                   })
      end

      it 'adds simple params' do
        params = Mobile::V0::Contracts::CommunityCareProviders.new.call({ facility_id: '1234',
                                                                          service_type: 'optometry' })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1&facilityId=1234&serviceType=optometry',
                                     first: 'http://example.com?page[size]=10&page[number]=1&facilityId=1234&serviceType=optometry',
                                     prev: nil,
                                     next: 'http://example.com?page[size]=10&page[number]=2&facilityId=1234&serviceType=optometry',
                                     last: 'http://example.com?page[size]=10&page[number]=2&facilityId=1234&serviceType=optometry'
                                   })
      end

      it 'adds array params' do
        params = Mobile::V0::Contracts::Appointments.new.call({ included: %w[1234 5678] })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1&included[]=1234&included[]=5678',
                                     first: 'http://example.com?page[size]=10&page[number]=1&included[]=1234&included[]=5678',
                                     prev: nil,
                                     next: 'http://example.com?page[size]=10&page[number]=2&included[]=1234&included[]=5678',
                                     last: 'http://example.com?page[size]=10&page[number]=2&included[]=1234&included[]=5678'
                                   })
      end

      it 'adds hash params' do
        params = Mobile::V0::Contracts::Prescriptions.new.call({ filter: { uno: { dos: 'tres' } } })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1&filter[[uno][dos]]=tres',
                                     first: 'http://example.com?page[size]=10&page[number]=1&filter[[uno][dos]]=tres',
                                     prev: nil,
                                     next: 'http://example.com?page[size]=10&page[number]=2&filter[[uno][dos]]=tres',
                                     last: 'http://example.com?page[size]=10&page[number]=2&filter[[uno][dos]]=tres'
                                   })
      end

      it 'skips params with blank values' do
        params = Mobile::V0::Contracts::CommunityCareProviders.new.call({ facility_id: nil, service_type: 'optometry' })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1&serviceType=optometry',
                                     first: 'http://example.com?page[size]=10&page[number]=1&serviceType=optometry',
                                     prev: nil,
                                     next: 'http://example.com?page[size]=10&page[number]=2&serviceType=optometry',
                                     last: 'http://example.com?page[size]=10&page[number]=2&serviceType=optometry'
                                   })
      end

      it 'adds params with false values' do
        params = Mobile::V0::Contracts::Appointments.new.call({ use_cache: false, reverse_sort: false })
        _resources, meta = described_class.paginate(list: list, validated_params: params, url: url)

        expect(meta[:links]).to eq({
                                     self: 'http://example.com?page[size]=10&page[number]=1&useCache=false&reverseSort=false',
                                     first: 'http://example.com?page[size]=10&page[number]=1&useCache=false&reverseSort=false',
                                     prev: nil,
                                     next: 'http://example.com?page[size]=10&page[number]=2&useCache=false&reverseSort=false',
                                     last: 'http://example.com?page[size]=10&page[number]=2&useCache=false&reverseSort=false'
                                   })
      end
    end
  end
end
