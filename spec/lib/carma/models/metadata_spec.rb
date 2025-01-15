# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/metadata'

RSpec.describe CARMA::Models::Metadata, type: :model do
  describe '#claim_id' do
    it 'is accessible' do
      subject.claim_id = 123
      expect(subject.claim_id).to eq(123)
    end
  end

  describe '#claim_guid' do
    it 'is accessible' do
      subject.claim_guid = 'my-uuid'
      expect(subject.claim_guid).to eq('my-uuid')
    end
  end

  describe '#submitted_at' do
    it 'is accessible' do
      claim_created_at = DateTime.now.iso8601
      subject.submitted_at = claim_created_at
      expect(subject.submitted_at).to eq(claim_created_at)
    end
  end

  describe '#veteran' do
    it 'is accessible' do
      subject.veteran = { icn: 'ABCD1234', is_veteran: true }

      expect(subject.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.veteran.icn).to eq('ABCD1234')
      expect(subject.veteran.is_veteran).to be(true)
    end
  end

  describe '#primary_caregiver' do
    it 'is accessible' do
      subject.primary_caregiver = { icn: 'ABCD1234' }

      expect(subject.primary_caregiver).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.primary_caregiver.icn).to eq('ABCD1234')
    end

    it 'can be set to nil' do
      subject.primary_caregiver = nil
      expect(subject.primary_caregiver).to be_nil
    end
  end

  describe '#secondary_caregiver_one' do
    it 'is accessible' do
      subject.secondary_caregiver_one = { icn: 'ABCD1234' }

      expect(subject.secondary_caregiver_one).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.secondary_caregiver_one.icn).to eq('ABCD1234')
    end

    it 'can be set to nil' do
      subject.secondary_caregiver_one = nil
      expect(subject.secondary_caregiver_one).to be_nil
    end
  end

  describe '#secondary_caregiver_two' do
    it 'is accessible' do
      subject.secondary_caregiver_two = { icn: 'ABCD1234' }

      expect(subject.secondary_caregiver_two).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.secondary_caregiver_two.icn).to eq('ABCD1234')
    end

    it 'can be set to nil' do
      subject.secondary_caregiver_two = nil
      expect(subject.secondary_caregiver_two).to be_nil
    end
  end

  describe '::new' do
    it 'initializes with defaults' do
      # Should default to empty described_class::Veteran
      expect(subject.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.veteran.icn).to be_nil
      expect(subject.veteran.is_veteran).to be_nil

      # Should default to nil
      expect(subject.primary_caregiver).to be_nil

      # Should default to nil
      expect(subject.secondary_caregiver_one).to be_nil

      # Should default to nil
      expect(subject.secondary_caregiver_two).to be_nil
    end

    it 'accepts claim_id, submitted_at, veteran, primary_caregiver, secondary_caregiver_one, secondary_caregiver_two' do
      claim_created_at = DateTime.now.iso8601
      subject = described_class.new(
        claim_id: 123,
        claim_guid: 'my-uuid',
        submitted_at: claim_created_at,
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
      )

      expect(subject.claim_id).to eq(123)
      expect(subject.claim_guid).to eq('my-uuid')
      expect(subject.submitted_at).to eq(claim_created_at)
      expect(subject.veteran.icn).to eq('VET1234')
      expect(subject.veteran.is_veteran).to be(true)
      expect(subject.primary_caregiver.icn).to eq('PC1234')
      expect(subject.secondary_caregiver_one.icn).to eq('SCO1234')
      expect(subject.secondary_caregiver_two.icn).to eq('SCT1234')
    end
  end

  describe '::request_payload_keys' do
    it 'inherits fron Base' do
      expect(described_class.ancestors).to include(CARMA::Models::Base)
    end

    it 'sets request_payload_keys' do
      expect(described_class.request_payload_keys).to eq(
        %i[
          claim_id
          claim_guid
          submitted_at
          veteran
          primary_caregiver
          secondary_caregiver_one
          secondary_caregiver_two
        ]
      )
    end
  end

  describe '#to_request_payload' do
    context 'with a minimal required data set' do
      context 'only containing primaryCaregiver' do
        it 'can receive :to_request_payload' do
          subject = described_class.new(
            claim_id: 123,
            claim_guid: 'my-uuid',
            primary_caregiver: {
              icn: 'PC1234'
            }
          )

          expect(subject.to_request_payload).to eq(
            {
              'claimId' => 123,
              'claimGuid' => 'my-uuid',
              'submittedAt' => nil,
              'veteran' => {
                'icn' => nil,
                'isVeteran' => nil
              },
              'primaryCaregiver' => {
                'icn' => 'PC1234'
              },
              'secondaryCaregiverOne' => nil,
              'secondaryCaregiverTwo' => nil
            }
          )
        end
      end

      context 'only containing secondaryCaregiverOne' do
        it 'can receive :to_request_payload' do
          subject = described_class.new(
            claim_id: 123,
            claim_guid: 'my-uuid',
            secondary_caregiver_one: {
              icn: 'SCO1234'
            }
          )

          expect(subject.to_request_payload).to eq(
            {
              'claimId' => 123,
              'claimGuid' => 'my-uuid',
              'submittedAt' => nil,
              'veteran' => {
                'icn' => nil,
                'isVeteran' => nil
              },
              'primaryCaregiver' => nil,
              'secondaryCaregiverOne' => {
                'icn' => 'SCO1234'
              },
              'secondaryCaregiverTwo' => nil
            }
          )
        end
      end
    end

    context 'with a maximum data set' do
      it 'can receive :to_request_payload' do
        claim_created_at = DateTime.now.iso8601
        subject = described_class.new(
          claim_id: 123,
          claim_guid: 'my-uuid',
          submitted_at: claim_created_at,
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
        )

        expect(subject.to_request_payload).to eq(
          {
            'claimId' => 123,
            'claimGuid' => 'my-uuid',
            'submittedAt' => claim_created_at,
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
        )
      end
    end
  end
end
