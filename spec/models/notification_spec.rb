# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'validations' do
    it 'has a valid factory' do
      notification = build :notification

      expect(notification).to be_valid
    end
  end

  describe '.subjects' do
    it 'returns a hash of the enum values mapped to their database integers', :aggregate_failures do
      subjects = Notification.subjects

      expect(subjects[Notification::FORM_10_10EZ]).to eq 0
      expect(subjects[Notification::DASH_HCA]).to eq 1
    end
  end

  describe '.statuses' do
    it 'returns a hash of the enum values mapped to their database integers', :aggregate_failures do
      statuses = Notification.statuses

      expect(statuses[Notification::ACTIVEDUTY]).to eq 0
      expect(statuses[Notification::CANCELED_DECLINED]).to eq 1
      expect(statuses[Notification::CLOSED]).to eq 2
      expect(statuses[Notification::DECEASED]).to eq 3
      expect(statuses[Notification::ENROLLED]).to eq 4
      expect(statuses[Notification::INELIG_CHAMPVA]).to eq 5
      expect(statuses[Notification::INELIG_CHARACTER_OF_DISCHARGE]).to eq 6
      expect(statuses[Notification::INELIG_CITIZENS]).to eq 7
      expect(statuses[Notification::INELIG_FILIPINOSCOUTS]).to eq 8
      expect(statuses[Notification::INELIG_FUGITIVEFELON]).to eq 9
      expect(statuses[Notification::INELIG_GUARD_RESERVE]).to eq 10
      expect(statuses[Notification::INELIG_MEDICARE]).to eq 11
      expect(statuses[Notification::INELIG_NOT_ENOUGH_TIME]).to eq 12
      expect(statuses[Notification::INELIG_NOT_VERIFIED]).to eq 13
      expect(statuses[Notification::INELIG_OTHER]).to eq 14
      expect(statuses[Notification::INELIG_OVER65]).to eq 15
      expect(statuses[Notification::INELIG_REFUSEDCOPAY]).to eq 16
      expect(statuses[Notification::INELIG_TRAINING_ONLY]).to eq 17
      expect(statuses[Notification::LOGIN_REQUIRED]).to eq 18
      expect(statuses[Notification::NONE]).to eq 19
      expect(statuses[Notification::PENDING_MT]).to eq 20
      expect(statuses[Notification::PENDING_OTHER]).to eq 21
      expect(statuses[Notification::PENDING_PURPLEHEART]).to eq 22
      expect(statuses[Notification::PENDING_UNVERIFIED]).to eq 23
      expect(statuses[Notification::REJECTED_INC_WRONGENTRY]).to eq 24
      expect(statuses[Notification::REJECTED_RIGHTENTRY]).to eq 25
      expect(statuses[Notification::REJECTED_SC_WRONGENTRY]).to eq 26
    end
  end

  describe '#subject' do
    it 'can only be set to an existing enum value', :aggregate_failures do
      expect { create :notification, subject: 'random_subject' }.to raise_error do |e|
        expect(e.class).to eq ArgumentError
        expect(e.message).to include 'is not a valid subject'
      end
    end
  end

  describe '#status' do
    it 'can only be set to an existing enum value', :aggregate_failures do
      expect { create :notification, status: 'random_status' }.to raise_error do |e|
        expect(e.class).to eq ArgumentError
        expect(e.message).to include 'is not a valid status'
      end
    end
  end
end
