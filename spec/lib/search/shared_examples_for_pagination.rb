# frozen_string_literal: true

require 'rails_helper'

shared_examples 'pagination data' do
  context 'when requesting page 1 of results' do
    subject { described_class.new(query, 1) }

    it 'returns the correct pagination information' do
      VCR.use_cassette('search/page_1') do
        pagination = subject.results['pagination']
        expect(pagination).to include('current_page' => 1)
        expect(pagination).to include('total_pages' => 9)
      end
    end
  end

  context 'when requesting page 2 of results' do
    subject { described_class.new(query, 2) }

    it 'returns the correct pagination information' do
      VCR.use_cassette('search/page_2') do
        pagination = subject.results['pagination']

        expect(pagination).to include('current_page' => 2)
        expect(pagination).to include('total_pages' => 9)
      end
    end
  end

  context 'when requesting last page of results' do
    subject { described_class.new(query, 9) }

    it 'returns the correct pagination information for the last page' do
      VCR.use_cassette('search/last_page') do
        pagination = subject.results['pagination']

        expect(pagination).to include('current_page' => 9)
        expect(pagination).to include('total_pages' => 9)
      end
    end
  end
end
