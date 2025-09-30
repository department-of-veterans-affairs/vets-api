# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaimGroup, type: :model do
  let(:parent) { create(:fake_saved_claim, id: 23) }
  let(:child) { create(:fake_saved_claim, id: 42) }

  let(:guid) { SecureRandom.uuid }

  before do
    allow_any_instance_of(SavedClaim).to receive :after_create_metrics
  end

  context 'a valid entry' do
    it 'tracks a create event' do
      tags = ["form_id:#{parent.form_id}", 'action:create']
      expect(StatsD).to receive(:increment).with('saved_claim_group', tags:)
      expect(Rails.logger).to receive(:info).with(/#{parent.form_id} 23 child #{child.form_id} 42/)

      SavedClaimGroup.new(claim_group_guid: guid, parent_claim_id: parent.id, saved_claim_id: child.id).save
    end

    it 'returns expected claims' do
      group = SavedClaimGroup.new(claim_group_guid: guid, parent_claim_id: parent.id, saved_claim_id: child.id)
      group.save

      expect(group.parent).to eq parent
      expect(group.child).to eq child
      expect(group.children.first).to eq child
    end

    it 'can be found from the parent claim' do
      group = SavedClaimGroup.new(claim_group_guid: guid, parent_claim_id: parent.id, saved_claim_id: child.id)
      group.save

      expect(parent.parent_of_groups).to eq [group]
    end

    it 'returns child claims excluding parent' do
      # Parent record (where parent_claim_id == saved_claim_id)
      create(:saved_claim_group,
             parent_claim_id: parent.id,
             saved_claim_id: parent.id)

      # Child record
      child_group = create(:saved_claim_group,
                           parent_claim_id: parent.id,
                           saved_claim_id: child.id)

      results = described_class.child_claims_for(parent.id)

      expect(results).to eq([child_group])
    end
  end
end
