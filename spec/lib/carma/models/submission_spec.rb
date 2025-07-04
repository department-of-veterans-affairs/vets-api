# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/submission'

RSpec.describe CARMA::Models::Submission, type: :model do
  describe '#carma_case_id' do
    it 'is accessible' do
      value = 'aB935000000A9GoCAK'

      subject.carma_case_id = value
      expect(subject.carma_case_id).to eq(value)
    end
  end

  describe '#submitted_at' do
    it 'is accessible' do
      value = DateTime.now.iso8601

      subject.submitted_at = value
      expect(subject.submitted_at).to eq(value)
    end
  end

  describe '#data' do
    it 'is accessible' do
      value = { 'my' => 'data' }

      subject.data = value
      expect(subject.data).to eq(value)
    end
  end

  describe '#metadata' do
    it 'is accessible' do
      subject.metadata = {
        claim_id: 123,
        claim_guid: 'my-uuid',
        veteran: {
          icn: 'VET1234',
          is_veteran: true
        },
        primary_caregiver: {
          icn: 'PC1234'
        },
        secondary_caregiver_one: {
          icn: 'SCO1234'
        },
        secondary_caregiver_two: {
          icn: 'SCT1234'
        }
      }

      # metadata
      expect(subject.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(subject.metadata.claim_id).to eq(123)
      expect(subject.metadata.claim_guid).to eq('my-uuid')
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.metadata.veteran.icn).to eq('VET1234')
      expect(subject.metadata.veteran.is_veteran).to be(true)
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.primary_caregiver.icn).to eq('PC1234')
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.secondary_caregiver_one.icn).to eq('SCO1234')
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.secondary_caregiver_two.icn).to eq('SCT1234')
    end
  end

  describe '::new' do
    it 'initializes with defaults' do
      expect(subject.carma_case_id).to be_nil
      expect(subject.submitted_at).to be_nil
      expect(subject.data).to be_nil
      # metadata
      expect(subject.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(subject.metadata.claim_id).to be_nil
      expect(subject.metadata.claim_guid).to be_nil
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.metadata.veteran.icn).to be_nil
      expect(subject.metadata.veteran.is_veteran).to be_nil
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_nil
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to be_nil
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to be_nil
    end

    it 'accepts :carma_case_id, :submitted_at, :data, and :metadata' do
      expected = {
        carma_case_id: 'aB935000000A9GoCAK',
        submitted_at: DateTime.now.iso8601,
        data: {
          'my' => 'data'
        }
      }

      subject = described_class.new(
        carma_case_id: expected[:carma_case_id],
        submitted_at: expected[:submitted_at],
        data: expected[:data],
        metadata: {
          claim_id: 123,
          claim_guid: 'my-uuid',
          veteran: {
            icn: 'VET1234',
            is_veteran: true
          },
          primary_caregiver: {
            icn: 'PC1234'
          },
          secondary_caregiver_one: {
            icn: 'SCO1234'
          },
          secondary_caregiver_two: {
            icn: 'SCT1234'
          }
        }
      )

      expect(subject.carma_case_id).to eq(expected[:carma_case_id])
      expect(subject.submitted_at).to eq(expected[:submitted_at])
      expect(subject.data).to eq(expected[:data])
      # metadata
      expect(subject.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(subject.metadata.claim_id).to eq(123)
      expect(subject.metadata.claim_guid).to eq('my-uuid')
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.metadata.veteran.icn).to eq('VET1234')
      expect(subject.metadata.veteran.is_veteran).to be(true)
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.primary_caregiver.icn).to eq('PC1234')
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.secondary_caregiver_one.icn).to eq('SCO1234')
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.metadata.secondary_caregiver_two.icn).to eq('SCT1234')
    end
  end

  describe '::from_claim' do
    it 'transforms a CaregiversAssistanceClaim to a new CARMA::Model::Submission' do
      submitted_at = DateTime.now - 1.second
      allow(Time).to receive(:now).and_return(submitted_at)
      claim = build(:caregivers_assistance_claim, created_at: DateTime.now)

      submission = described_class.from_claim(claim)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to be_nil

      expect(submission.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
      expect(submission.metadata.claim_guid).to eq(claim.guid)
      expect(submission.metadata.submitted_at).to eq(submitted_at.utc.iso8601)
    end

    it 'overrides :claim_id when passed in metadata and use claim.id instead' do
      created_at = DateTime.now
      claim = build(:caregivers_assistance_claim, created_at:)
      submitted_at = created_at + 1.second
      allow(Time).to receive(:now).and_return(submitted_at)

      submission = described_class.from_claim(claim, claim_id: 99)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to be_nil
      expect(submission.submitted_at).to be_nil

      expect(submission.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
      expect(submission.metadata.submitted_at).to eq(submitted_at.utc.iso8601)
      # expect(submission.metadata.submitted_at).to eq(claim.created_at.iso8601)
    end

    it 'overrides :claim_guid when passed in metadata and use claim.guid instead' do
      created_at = DateTime.now
      claim = build(:caregivers_assistance_claim, created_at:)
      submitted_at = created_at + 1.second
      allow(Time).to receive(:now).and_return(submitted_at)

      submission = described_class.from_claim(claim, claim_guid: 'not-this-claims-guid')

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to be_nil
      expect(submission.submitted_at).to be_nil

      expect(submission.metadata).to be_instance_of(CARMA::Models::Metadata)
      expect(submission.metadata.claim_guid).not_to eq('not-this-claims-guid')
      expect(submission.metadata.claim_guid).to eq(claim.guid)
      expect(submission.metadata.submitted_at).to eq(submitted_at.utc.iso8601)
    end
  end

  describe '::request_payload_keys' do
    it 'inherits fron Base' do
      expect(described_class.ancestors).to include(CARMA::Models::Base)
    end

    it 'sets request_payload_keys' do
      expect(described_class.request_payload_keys).to eq(%i[data metadata])
    end
  end

  describe '#to_request_payload' do
    it 'can receive :to_request_payload' do
      subject = described_class.new(
        data: {
          'my' => 'data'
        },
        metadata: {
          claim_id: 123,
          claim_guid: 'my-uuid',
          veteran: {
            icn: 'VET1234',
            is_veteran: true
          },
          primary_caregiver: {
            icn: 'PC1234'
          },
          secondary_caregiver_one: {
            icn: 'SCO1234'
          },
          secondary_caregiver_two: {
            icn: 'SCT1234'
          }
        }
      )

      expect(subject.to_request_payload).to eq(
        {
          'data' => {
            'my' => 'data'
          },
          'metadata' => {
            'claimId' => 123,
            'claimGuid' => 'my-uuid',
            'submittedAt' => nil,
            'veteran' => {
              'icn' => 'VET1234',
              'isVeteran' => true
            },
            'primaryCaregiver' => {
              'icn' => 'PC1234'
            },
            'secondaryCaregiverOne' => {
              'icn' => 'SCO1234'
            },
            'secondaryCaregiverTwo' => {
              'icn' => 'SCT1234'
            }
          }
        }
      )
    end
  end
end
