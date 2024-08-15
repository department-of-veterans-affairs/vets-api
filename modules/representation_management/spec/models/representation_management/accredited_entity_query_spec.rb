# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedEntityQuery, type: :model do
  describe '#results' do
    it 'returns nothing for a blank query string' do
      expect(described_class.new('').results).to be_empty
    end

    it 'returns individuals and organizations in the sorted order' do
      create(:accredited_individual, full_name: 'Bob Law')
      create(:accredited_organization, name: 'Bob Law Firm')
      create(:accredited_individual, full_name: 'Bob Smith')
      create(:accredited_organization, name: 'Bob Smith Firm')

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
      create(:accredited_individual, full_name: 'aaaabc')
      create(:accredited_individual, full_name: 'aaaab')
      create(:accredited_individual, full_name: 'aaaabcde')
      create(:accredited_individual, full_name: 'aaaa')
      create(:accredited_individual, full_name: 'aaaabcd')

      results = described_class.new('aaaa').results

      expect(results.map(&:full_name)).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
    end

    it 'sorts organizations by levenshtein distance' do
      create(:accredited_organization, name: 'aaaabc')
      create(:accredited_organization, name: 'aaaab')
      create(:accredited_organization, name: 'aaaabcde')
      create(:accredited_organization, name: 'aaaa')
      create(:accredited_organization, name: 'aaaabcd')

      results = described_class.new('aaaa').results

      expect(results.map(&:name)).to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
    end

    it 'sorts individuals and organizations together by levenshtein distance' do
      create(:accredited_individual, full_name: 'aaaabc')
      create(:accredited_individual, full_name: 'aaaab')
      create(:accredited_organization, name: 'aaaabcde')
      create(:accredited_organization, name: 'aaaa')
      create(:accredited_individual, full_name: 'aaaabcd')

      results = described_class.new('aaaa').results

      expect(results.map { |r| r.is_a?(AccreditedIndividual) ? r.full_name : r.name })
        .to eq(%w[aaaa aaaab aaaabc aaaabcd aaaabcde])
    end

    it 'can return organizations as the first result' do
      create(:accredited_individual, full_name: 'Bob Billy Bill Bo')
      create(:accredited_organization, name: 'Bob Law Firm')

      results = described_class.new('Bob').results

      expect(results.size).to eq(2)
      expect(results.first).to be_a(AccreditedOrganization)
      expect(results.first.name).to eq('Bob Law Firm')
    end

    it 'returns at most 10 results' do
      create_list(:accredited_individual, 20, full_name: 'Bob')

      results = described_class.new('Bob').results

      expect(results.size).to eq(10)
    end
  end
end
