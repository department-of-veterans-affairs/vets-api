# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedEntityQuery, type: :model do
  let!(:individual1) { create(:accredited_individual, :with_location, full_name: 'Bob Law') }
  let!(:individual2) { create(:accredited_individual, :with_location, full_name: 'Bob Smith') }
  let!(:individual3) { create(:accredited_individual, :with_location, :attorney, full_name: 'aaaabc') }
  let!(:individual4) { create(:accredited_individual, :with_location, :claims_agent, full_name: 'aaaab') }
  let!(:individual5) { create(:accredited_individual, :with_location, full_name: 'aaaabcde') }
  let!(:individual6) { create(:accredited_individual, :with_location, full_name: 'aaaa') }
  let!(:individual7) { create(:accredited_individual, :with_location, full_name: 'aaaabcd') }

  let!(:organization1) { create(:accredited_organization, :with_location, name: 'Bob Law Firm') }
  let!(:organization2) { create(:accredited_organization, :with_location, name: 'Bob Smith Firm') }
  let!(:organization3) { create(:accredited_organization, :with_location, name: 'aaaabcdefgh') }
  let!(:organization4) { create(:accredited_organization, :with_location, name: 'aaaabcdefg') }
  let!(:organization5) { create(:accredited_organization, :with_location, name: 'aaaabcdefghij') }
  let!(:organization6) { create(:accredited_organization, :with_location, name: 'aaaabcdef') }
  let!(:organization7) { create(:accredited_organization, :with_location, name: 'aaaabcdefghi') }

  describe '#results' do
    it 'returns nothing for a blank query string' do
      expect(described_class.new('').results).to be_empty
    end

    it 'returns individuals and organizations in the sorted order' do
      results = described_class.new('Bob').results

      expect(results.size).to eq(4)
      expect(results.first).to be_a(AccreditedIndividual)
      expect(results.first.full_name).to eq('Bob Law')
      expect(results.second).to be_a(AccreditedIndividual)
      expect(results.second.full_name).to eq('Bob Smith')
      expect(results.third).to be_a(AccreditedOrganization)
      expect(results.third.name).to eq('Bob Law Firm')
      expect(results.last).to be_a(AccreditedOrganization)
      expect(results.last.name).to eq('Bob Smith Firm')
    end

    it 'sorts individuals by levenshtein distance' do
      results = described_class.new('aaaa').results
      individual_results = results.select { |result| result.is_a?(AccreditedIndividual) }

      expect(individual_results.map(&:full_name)).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
    end

    it 'sorts organizations by levenshtein distance' do
      results = described_class.new('aaaa').results
      organization_results = results.select { |result| result.is_a?(AccreditedOrganization) }

      expect(organization_results.map(&:name)).to eq(%w[aaaabcdef aaaabcdefg aaaabcdefgh aaaabcdefghi aaaabcdefghij])
    end

    it 'sorts individuals and organizations together by levenshtein distance' do
      results = described_class.new('aaaa').results

      expect(results.size).to eq(10)
      expect(results.map(&:id)).to eq([individual6.id,
                                       individual4.id,
                                       individual3.id,
                                       individual7.id,
                                       individual5.id,
                                       organization6.id,
                                       organization4.id,
                                       organization3.id,
                                       organization7.id,
                                       organization5.id])
    end

    it 'can return organizations as the first result' do
      results = described_class.new('Bob Law Firm').results

      expect(results.first).to be_a(AccreditedOrganization)
      expect(results.first.name).to eq('Bob Law Firm')
    end

    it 'returns at most 10 results' do
      create_list(:accredited_individual, 20, :with_location, full_name: 'Bob')

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
