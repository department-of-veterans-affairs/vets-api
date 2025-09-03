# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedEntityQuery, type: :model do
  let!(:individual1) do
    create(:veteran_representative, :with_address, representative_id: 'rep1', first_name: 'Bob', last_name: 'Law')
  end
  let!(:individual2) do
    create(:veteran_representative, :with_address, representative_id: 'rep2', first_name: 'Bob', last_name: 'Smith')
  end
  let!(:individual3) do
    create(:veteran_representative, :with_address, representative_id: 'rep3', first_name: 'aaaabc', last_name: '')
  end
  let!(:individual4) do
    create(:veteran_representative, :with_address, representative_id: 'rep4', first_name: 'aaaab', last_name: '')
  end
  let!(:individual5) do
    create(:veteran_representative, :with_address, representative_id: 'rep5', first_name: 'aaaabcde', last_name: '')
  end
  let!(:individual6) do
    create(:veteran_representative, :with_address, representative_id: 'rep6', first_name: 'aaaa', last_name: '')
  end
  let!(:individual7) do
    create(:veteran_representative, :with_address, representative_id: 'rep7', first_name: 'aaaabcd', last_name: '')
  end

  let!(:organization1) { create(:veteran_organization, name: 'Bob Law Firm') }
  let!(:organization2) { create(:veteran_organization, name: 'Bob Smith Firm') }
  let!(:organization3) { create(:veteran_organization, name: 'aaaabcdefgh') }
  let!(:organization4) { create(:veteran_organization, name: 'aaaabcdefg') }
  let!(:organization5) { create(:veteran_organization, name: 'aaaabcdefghij') }
  let!(:organization6) { create(:veteran_organization, name: 'aaaabcdef') }
  let!(:organization7) { create(:veteran_organization, name: 'aaaabcdefghi') }

  describe '#results' do
    it 'returns nothing for a blank query string' do
      expect(described_class.new('').results).to be_empty
    end

    it 'returns individuals and organizations in the sorted order' do
      results = described_class.new('Bob').results

      expect(results.size).to eq(4)
  expect(results.first).to be_a(Veteran::Service::Representative)
      expect(results.first.full_name).to eq('Bob Law')
  expect(results.second).to be_a(Veteran::Service::Representative)
      expect(results.second.full_name).to eq('Bob Smith')
  expect(results.third).to be_a(Veteran::Service::Organization)
      expect(results.third.name).to eq('Bob Law Firm')
  expect(results.last).to be_a(Veteran::Service::Organization)
      expect(results.last.name).to eq('Bob Smith Firm')
    end

    it 'sorts individuals by levenshtein distance' do
      results = described_class.new('aaaa').results
  individual_results = results.select { |result| result.is_a?(Veteran::Service::Representative) }

      expect(individual_results.map(&:full_name)).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
    end

    it 'sorts organizations by levenshtein distance' do
      results = described_class.new('aaaa').results
  organization_results = results.select { |result| result.is_a?(Veteran::Service::Organization) }

      expect(organization_results.map(&:name)).to eq(%w[aaaabcdef aaaabcdefg aaaabcdefgh aaaabcdefghi aaaabcdefghij])
    end

    it 'sorts individuals and organizations together by levenshtein distance' do
      results = described_class.new('aaaa').results

      expect(results.size).to eq(10)
      expect(results.map(&:id)).to eq([
        individual6.id,
        individual4.id,
        individual3.id,
        individual7.id,
        individual5.id,
        organization6.id,
        organization4.id,
        organization3.id,
        organization7.id,
        organization5.id
      ])
    end

    it 'can return organizations as the first result' do
      results = described_class.new('Bob Law Firm').results

  expect(results.first).to be_a(Veteran::Service::Organization)
      expect(results.first.name).to eq('Bob Law Firm')
    end

    it 'returns at most 10 results' do
      create_list(:accredited_individual, 20, :with_location, first_name: 'Bob', last_name: '')

      results = described_class.new('Bob').results

      expect(results.size).to eq(10)
    end

    it "returns 9 results with a query of 'aaaab' and the standard threshold" do
      results = described_class.new('aaaab').results

      expect(results.size).to eq(9)
    end

    it "returns more than 9 results with a query of 'aaaab' and a threshold of 0.5" do
      stub_const('RepresentationManagement::AccreditedEntityQuery::WORD_SIMILARITY_THRESHOLD', 0.5)
      results = described_class.new('aaaab').results

      expect(results.size).to be > 9
    end

    it "returns less than 9 results with a query of 'aaaab' and a threshold of 0.9" do
      stub_const('RepresentationManagement::AccreditedEntityQuery::WORD_SIMILARITY_THRESHOLD', 0.9)
      results = described_class.new('aaaab').results

      expect(results.size).to be < 9
    end
  end
end
