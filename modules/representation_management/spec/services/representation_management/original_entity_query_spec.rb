# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::OriginalEntityQuery, type: :model do
  let!(:individual1) do
    create(:representative, :with_address, :vso, first_name: 'Bob', last_name: 'Law', representative_id: '00000')
  end
  let!(:individual2) do
    create(:representative, :with_address, :vso, first_name: 'Bob', last_name: 'Smith', representative_id: '00001')
  end
  let!(:individual3) do
    create(:representative, :with_address, first_name: 'aaaabc', last_name: nil, representative_id: '00002')
  end
  let!(:individual4) do
    create(:representative, :with_address, :claim_agents, first_name: 'aaaab', last_name: nil,
                                                          representative_id: '00003')
  end
  let!(:individual5) do
    create(:representative, :with_address, :vso, first_name: 'aaaabcde', last_name: nil, representative_id: '00004')
  end
  let!(:individual6) do
    create(:representative, :with_address, :vso, first_name: 'aaaa', last_name: nil, representative_id: '00005')
  end
  let!(:individual7) do
    create(:representative, :with_address, :vso, first_name: 'aaaabcd', last_name: nil, representative_id: '00006')
  end

  let!(:organization1) { create(:organization, :with_address, name: 'Bob Law Firm', poa: '007') }
  let!(:organization2) { create(:organization, :with_address, name: 'Bob Smith Firm', poa: '008') }
  let!(:organization3) { create(:organization, :with_address, name: 'aaaabcdefgh', poa: '009') }
  let!(:organization4) { create(:organization, :with_address, name: 'aaaabcdefg', poa: '010') }
  let!(:organization5) { create(:organization, :with_address, name: 'aaaabcdefghij', poa: '011') }
  let!(:organization6) { create(:organization, :with_address, name: 'aaaabcdef', poa: '012') }
  let!(:organization7) { create(:organization, :with_address, name: 'aaaabcdefghi', poa: '013') }

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
      expect(results.map(&:id)).to eq([individual6.representative_id,
                                       individual4.representative_id,
                                       individual3.representative_id,
                                       individual7.representative_id,
                                       individual5.representative_id,
                                       organization6.poa,
                                       organization4.poa,
                                       organization3.poa,
                                       organization7.poa,
                                       organization5.poa])
    end

    it 'can return organizations as the first result' do
      results = described_class.new('Bob Law Firm').results

      expect(results.first).to be_a(Veteran::Service::Organization)
      expect(results.first.name).to eq('Bob Law Firm')
    end

    it 'returns at most 10 results' do
      20.times do |index|
        create(:representative, :with_address, full_name: 'Bob', representative_id: index.to_s)
      end

      results = described_class.new('Bob').results

      expect(results.size).to eq(10)
    end

    it "returns 9 results with a query of 'aaaab' and the standard threshold" do
      results = described_class.new('aaaab').results

      expect(results.size).to eq(9)
    end

    it "returns more than 9 results with a query of 'aaaab' and a threshold of 0.5" do
      stub_const('RepresentationManagement::OriginalEntityQuery::WORD_SIMILARITY_THRESHOLD', 0.5)
      results = described_class.new('aaaab').results

      expect(results.size).to be > 9
    end

    it "returns less than 9 results with a query of 'aaaab' and a threshold of 0.9" do
      stub_const('RepresentationManagement::OriginalEntityQuery::WORD_SIMILARITY_THRESHOLD', 0.9)
      results = described_class.new('aaaab').results

      expect(results.size).to be < 9
    end
  end
end
