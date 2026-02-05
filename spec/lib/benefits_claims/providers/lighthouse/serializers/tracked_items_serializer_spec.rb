# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/lighthouse/serializers/tracked_items_serializer'
require 'benefits_claims/responses/claim_response'

RSpec.describe BenefitsClaims::Providers::Lighthouse::Serializers::TrackedItemsSerializer do
  describe '.serialize' do
    let(:tracked_item) do
      BenefitsClaims::Responses::TrackedItem.new(
        id: 123,
        display_name: 'PMR Pending',
        status: 'NEEDED_FROM_YOU',
        type: 'other',
        description: 'Please submit your private medical records',
        overdue: false,
        suspense_date: '2026-12-01',
        closed_date: nil,
        received_date: nil,
        requested_date: '2024-11-01',
        date: '2024-11-01',
        uploads_allowed: true,
        uploaded: false,
        can_upload_file: true,
        documents: '[]',
        friendly_name: 'Private Medical Records',
        friendly_description: 'We need your medical records from private providers',
        activity_description: 'Submit records',
        short_description: 'Medical records needed',
        support_aliases: %w[PMR Medical]
      )
    end

    it 'converts TrackedItem objects to JSON data' do
      result = described_class.serialize([tracked_item])

      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first).to be_a(Hash)
    end

    it 'correctly serializes core fields' do
      serialized = described_class.serialize([tracked_item]).first

      expect(serialized['id']).to eq(123)
      expect(serialized['displayName']).to eq('PMR Pending')
      expect(serialized['status']).to eq('NEEDED_FROM_YOU')
      expect(serialized['type']).to eq('other')
      expect(serialized['description']).to eq('Please submit your private medical records')
      expect(serialized['overdue']).to be(false)
    end

    it 'correctly serializes date fields' do
      serialized = described_class.serialize([tracked_item]).first

      expect(serialized['suspenseDate']).to eq('2026-12-01')
      expect(serialized['closedDate']).to be_nil
      expect(serialized['receivedDate']).to be_nil
      expect(serialized['requestedDate']).to eq('2024-11-01')
      expect(serialized['date']).to eq('2024-11-01')
    end

    it 'correctly serializes upload fields' do
      serialized = described_class.serialize([tracked_item]).first

      expect(serialized['uploadsAllowed']).to be(true)
      expect(serialized['uploaded']).to be(false)
      expect(serialized['canUploadFile']).to be(true)
      expect(serialized['documents']).to eq('[]')
    end

    it 'correctly serializes display fields' do
      long_desc = { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Detailed description' }] }
      next_steps_content = { 'blocks' => [{ 'type' => 'paragraph', 'content' => 'Next steps' }] }

      item = BenefitsClaims::Responses::TrackedItem.new(
        id: 456,
        display_name: '21-4142/21-4142a',
        status: 'NEEDED_FROM_YOU',
        friendly_name: 'Authorization to disclose information',
        friendly_description: 'We need authorization to get your records',
        support_aliases: ['21-4142/21-4142a'],
        # Some content override fields present
        long_description: long_desc,
        next_steps: next_steps_content,
        is_sensitive: true,
        # Some content override fields absent (nil)
        no_action_needed: nil,
        is_dbq: nil,
        is_proper_noun: nil,
        no_provide_prefix: nil
      )

      serialized = described_class.serialize([item]).first

      # Display fields are always present
      expect(serialized['friendlyName']).to eq('Authorization to disclose information')
      expect(serialized['friendlyDescription']).to eq('We need authorization to get your records')
      expect(serialized['supportAliases']).to eq(['21-4142/21-4142a'])
      # Present content override fields are included
      expect(serialized['longDescription']).to eq(long_desc)
      expect(serialized['nextSteps']).to eq(next_steps_content)
      expect(serialized['isSensitive']).to be(true)
      # Absent content override fields are not included
      expect(serialized).not_to have_key('noActionNeeded')
      expect(serialized).not_to have_key('isDBQ')
      expect(serialized).not_to have_key('isProperNoun')
      expect(serialized).not_to have_key('noProvidePrefix')
    end
  end
end
