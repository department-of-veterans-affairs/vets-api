# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/lighthouse/builders/tracked_items_builder'
require 'benefits_claims/responses/claim_response'

RSpec.describe BenefitsClaims::Providers::Lighthouse::Builders::TrackedItemsBuilder do
  describe '#build' do
    it 'returns nil when input is nil' do
      expect(described_class.build(nil)).to be_nil
    end

    it 'returns empty array when input is empty' do
      expect(described_class.build([])).to eq([])
    end

    it 'converts JSON data to TrackedItem objects' do
      long_desc = { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Details' }] }
      next_steps = { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Steps' }] }

      data = [{
        'id' => 123,
        'displayName' => 'Test Item',
        'status' => 'NEEDED_FROM_YOU',
        'longDescription' => long_desc,
        'nextSteps' => next_steps,
        'noActionNeeded' => false,
        'isDBQ' => true,
        'isProperNoun' => false,
        'isSensitive' => true,
        'noProvidePrefix' => false
      }]

      item = described_class.build(data).first

      expect(item).to be_a(BenefitsClaims::Responses::TrackedItem)
      expect(item.id).to eq(123)
      expect(item.display_name).to eq('Test Item')
      expect(item.status).to eq('NEEDED_FROM_YOU')
      expect(item.long_description).to eq(long_desc)
      expect(item.next_steps).to eq(next_steps)
      expect(item.no_action_needed).to be(false)
      expect(item.is_dbq).to be(true)
      expect(item.is_proper_noun).to be(false)
      expect(item.is_sensitive).to be(true)
      expect(item.no_provide_prefix).to be(false)
    end

    it 'handles missing content override fields gracefully' do
      data = [{ 'id' => 789, 'displayName' => 'Unknown Item' }]
      item = described_class.build(data).first

      expect(item.long_description).to be_nil
      expect(item.next_steps).to be_nil
      expect(item.no_action_needed).to be_nil
    end
  end
end
