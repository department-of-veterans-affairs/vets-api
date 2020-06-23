# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Models::Metadata, type: :model do
  describe '#claim_id' do
    it 'is accessible' do
      subject.claim_id = 123
      expect(subject.claim_id).to eq(123)
    end
  end

  describe '#veteran' do
    it 'is accessible' do
      subject.veteran = { icn: 'ABCD1234', is_veteran: true }

      expect(subject.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.veteran.icn).to eq('ABCD1234')
      expect(subject.veteran.is_veteran).to eq(true)
    end
  end

  describe '#primary_caregiver' do
    it 'is accessible' do
      subject.primary_caregiver = { icn: 'ABCD1234' }

      expect(subject.primary_caregiver).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.primary_caregiver.icn).to eq('ABCD1234')
    end
  end

  describe '#secondary_caregiver_one' do
    it 'is accessible' do
      subject.secondary_caregiver_one = { icn: 'ABCD1234' }

      expect(subject.secondary_caregiver_one).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.secondary_caregiver_one.icn).to eq('ABCD1234')
    end

    it 'is can be set to nil' do
      subject.secondary_caregiver_one = nil
      expect(subject.secondary_caregiver_one).to eq(nil)
    end
  end

  describe '#secondary_caregiver_two' do
    it 'is accessible' do
      subject.secondary_caregiver_two = { icn: 'ABCD1234' }

      expect(subject.secondary_caregiver_two).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.secondary_caregiver_two.icn).to eq('ABCD1234')
    end

    it 'is can be set to nil' do
      subject.secondary_caregiver_two = nil
      expect(subject.secondary_caregiver_two).to eq(nil)
    end
  end

  describe '::new' do
    it 'initializes with defaults' do
      # Should default to empty described_class::Veteran
      expect(subject.veteran).to be_instance_of(CARMA::Models::Veteran)
      expect(subject.veteran.icn).to eq(nil)
      expect(subject.veteran.is_veteran).to eq(nil)

      # Should default to empty described_class::Caregiver
      expect(subject.primary_caregiver).to be_instance_of(CARMA::Models::Caregiver)
      expect(subject.primary_caregiver.icn).to eq(nil)

      # Should default to nil
      expect(subject.secondary_caregiver_one).to eq(nil)

      # Should default to nil
      expect(subject.secondary_caregiver_two).to eq(nil)
    end

    it 'accepts :claim_id, :veteran, :primary_caregiver, :secondary_caregiver_one, :secondary_caregiver_two' do
      subject = described_class.new(
        claim_id: 123,
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
      expect(subject.veteran.icn).to eq('VET1234')
      expect(subject.veteran.is_veteran).to eq(true)
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
          veteran
          primary_caregiver
          secondary_caregiver_one
          secondary_caregiver_two
        ]
      )
    end
  end

  describe '#to_request_payload' do
    describe 'can receive :to_request_payload' do
      it 'with a minimal data set' do
        subject = described_class.new claim_id: 123

        expect(subject.to_request_payload).to eq(
          {
            'claimId' => 123,
            'veteran' => {
              'icn' => nil,
              'isVeteran' => nil
            },
            'primaryCaregiver' => {
              'icn' => nil
            },
            'secondaryCaregiverOne' => nil,
            'secondaryCaregiverTwo' => nil
          }
        )
      end

      it 'with a maximum data set' do
        subject = described_class.new(
          claim_id: 123,
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
