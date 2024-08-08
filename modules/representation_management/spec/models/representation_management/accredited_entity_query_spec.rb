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
      create(:accredited_individual, full_name: 'abc')
      create(:accredited_individual, full_name: 'ab')
      create(:accredited_individual, full_name: 'abcde')
      create(:accredited_individual, full_name: 'a')
      create(:accredited_individual, full_name: 'abcd')

      results = described_class.new('a').results

      expect(results.map(&:full_name)).to eq(%w[a ab abc abcd abcde])
    end

    it 'sorts organizations by levenshtein distance' do
      create(:accredited_organization, name: 'abc')
      create(:accredited_organization, name: 'ab')
      create(:accredited_organization, name: 'abcde')
      create(:accredited_organization, name: 'a')
      create(:accredited_organization, name: 'abcd')

      results = described_class.new('a').results

      expect(results.map(&:name)).to eq(%w[a ab abc abcd abcde])
    end

    it 'sorts individuals and organizations together by levenshtein distance' do
      create(:accredited_individual, full_name: 'abc')
      create(:accredited_individual, full_name: 'ab')
      create(:accredited_organization, name: 'abcde')
      create(:accredited_organization, name: 'a')
      create(:accredited_individual, full_name: 'abcd')

      results = described_class.new('a').results

      expect(results.map { |r| r.is_a?(AccreditedIndividual) ? r.full_name : r.name })
        .to eq(%w[a ab abc abcd abcde])
    end
  end
end
