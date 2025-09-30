# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaimGroup, type: :model do
  let(:parent) { create(:fake_saved_claim, id: 23) }
  let(:child) { create(:fake_saved_claim, id: 42) }
  let(:child2) { create(:fake_saved_claim, id: 43) }

  let(:guid) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }

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
      expect(group.saved_claim_children.first).to eq child
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

  describe 'scopes' do
    let!(:parent_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: parent.id,
        status: 'pending'
      )
    end

    let!(:child_group1) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: child.id,
        status: 'success'
      )
    end

    let!(:child_group2) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: child2.id,
        status: 'pending',
        needs_kms_rotation: true
      )
    end

    let!(:other_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid2,
        parent_claim_id: child.id,
        saved_claim_id: child.id,
        status: 'pending'
      )
    end

    describe '.by_claim_group_guid' do
      it 'returns groups with matching claim_group_guid' do
        results = SavedClaimGroup.by_claim_group_guid(guid)
        expect(results).to contain_exactly(parent_group, child_group1, child_group2)
      end

      it 'returns empty collection when no matches' do
        nonexistent_guid = SecureRandom.uuid
        results = SavedClaimGroup.by_claim_group_guid(nonexistent_guid)
        expect(results).to be_empty
      end
    end

    describe '.by_saved_claim_id' do
      it 'returns groups with matching saved_claim_id' do
        results = SavedClaimGroup.by_saved_claim_id(child.id)
        expect(results).to contain_exactly(child_group1, other_group)
      end

      it 'returns empty collection when no matches' do
        results = SavedClaimGroup.by_saved_claim_id(999)
        expect(results).to be_empty
      end
    end

    describe '.by_parent_id' do
      it 'returns groups with matching parent_claim_id' do
        results = SavedClaimGroup.by_parent_id(parent.id)
        expect(results).to contain_exactly(parent_group, child_group1, child_group2)
      end

      it 'returns empty collection when no matches' do
        results = SavedClaimGroup.by_parent_id(999)
        expect(results).to be_empty
      end
    end

    describe '.by_status' do
      it 'returns groups with matching status' do
        results = SavedClaimGroup.by_status('pending')
        expect(results).to contain_exactly(parent_group, child_group2, other_group)
      end

      it 'returns groups with success status' do
        results = SavedClaimGroup.by_status('success')
        expect(results).to contain_exactly(child_group1)
      end

      it 'returns empty collection when no matches' do
        results = SavedClaimGroup.by_status('failure')
        expect(results).to be_empty
      end
    end

    describe '.pending' do
      it 'returns only pending groups' do
        results = SavedClaimGroup.pending
        expect(results).to contain_exactly(parent_group, child_group2, other_group)
      end
    end

    describe '.needs_kms_rotation' do
      it 'returns only groups that need KMS rotation' do
        results = SavedClaimGroup.needs_kms_rotation
        expect(results).to contain_exactly(child_group2)
      end
    end

    describe '.child_claims_for' do
      it 'returns child groups excluding parent for given parent_id' do
        results = SavedClaimGroup.child_claims_for(parent.id)
        expect(results).to contain_exactly(child_group1, child_group2)
      end

      it 'excludes the parent record itself' do
        results = SavedClaimGroup.child_claims_for(parent.id)
        expect(results).not_to include(parent_group)
      end

      it 'returns empty collection when no children exist' do
        results = SavedClaimGroup.child_claims_for(child.id)
        expect(results).to be_empty
      end
    end
  end

  describe '#parent_claim_group_for_child' do
    let!(:parent_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: parent.id
      )
    end

    let!(:child_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: child.id
      )
    end

    it 'returns the parent group record for a child group' do
      result = child_group.parent_claim_group_for_child
      expect(result).to eq(parent_group)
    end

    it 'returns self when called on parent group' do
      result = parent_group.parent_claim_group_for_child
      expect(result).to eq(parent_group)
    end

    it 'returns nil when parent group does not exist' do
      orphan_group = SavedClaimGroup.create!(
        claim_group_guid: guid2,
        parent_claim_id: child2.id,
        saved_claim_id: child.id
      )

      result = orphan_group.parent_claim_group_for_child
      expect(result).to be_nil
    end
  end

  describe '#children_of_group' do
    let!(:parent_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: parent.id
      )
    end

    let!(:child_group1) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: child.id
      )
    end

    let!(:child_group2) do
      SavedClaimGroup.create!(
        claim_group_guid: guid,
        parent_claim_id: parent.id,
        saved_claim_id: child2.id
      )
    end

    let!(:other_parent_group) do
      SavedClaimGroup.create!(
        claim_group_guid: guid2,
        parent_claim_id: child.id,
        saved_claim_id: child.id
      )
    end

    it 'returns child groups for the same parent, excluding the parent itself' do
      result = parent_group.children_of_group
      expect(result).to contain_exactly(child_group1, child_group2)
    end

    it 'excludes the parent group record itself' do
      result = parent_group.children_of_group
      expect(result).not_to include(parent_group)
    end

    it 'returns empty collection when no children exist' do
      result = other_parent_group.children_of_group
      expect(result).to be_empty
    end

    it 'works correctly when called from a child group' do
      result = child_group1.children_of_group
      expect(result).to contain_exactly(child_group1, child_group2)
    end

    it 'does not include groups from different parents' do
      result = parent_group.children_of_group
      expect(result).not_to include(other_parent_group)
    end
  end
end
