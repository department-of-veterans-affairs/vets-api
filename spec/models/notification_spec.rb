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
    let(:subjects) { Notification.subjects }

    it 'returns a hash of the enum values mapped to their database integers', :aggregate_failures do
      expect(subjects[:form_10_10ez]).to eq 0
      expect(subjects[:dashboard_health_care_application_notification]).to eq 1
    end

    it 'returns the correct number of established enum mappings' do
      expect(subjects.size).to eq 2
    end
  end

  describe '.statuses' do
    let(:statuses) { Notification.statuses }

    it 'returns a hash of the enum values mapped to their database integers', :aggregate_failures do
      expect(statuses[:activeduty]).to eq 0
      expect(statuses[:canceled_declined]).to eq 1
      expect(statuses[:closed]).to eq 2
      expect(statuses[:deceased]).to eq 3
      expect(statuses[:enrolled]).to eq 4
      expect(statuses[:inelig_champva]).to eq 5
      expect(statuses[:inelig_character_of_discharge]).to eq 6
      expect(statuses[:inelig_citizens]).to eq 7
      expect(statuses[:inelig_filipinoscouts]).to eq 8
      expect(statuses[:inelig_fugitivefelon]).to eq 9
      expect(statuses[:inelig_guard_reserve]).to eq 10
      expect(statuses[:inelig_medicare]).to eq 11
      expect(statuses[:inelig_not_enough_time]).to eq 12
      expect(statuses[:inelig_not_verified]).to eq 13
      expect(statuses[:inelig_other]).to eq 14
      expect(statuses[:inelig_over65]).to eq 15
      expect(statuses[:inelig_refusedcopay]).to eq 16
      expect(statuses[:inelig_training_only]).to eq 17
      expect(statuses[:login_required]).to eq 18
      expect(statuses[:none_of_the_above]).to eq 19
      expect(statuses[:pending_mt]).to eq 20
      expect(statuses[:pending_other]).to eq 21
      expect(statuses[:pending_purpleheart]).to eq 22
      expect(statuses[:pending_unverified]).to eq 23
      expect(statuses[:rejected_inc_wrongentry]).to eq 24
      expect(statuses[:rejected_rightentry]).to eq 25
      expect(statuses[:rejected_sc_wrongentry]).to eq 26
      expect(statuses[:non_military]).to eq 27
    end

    it 'returns the correct number of established enum mappings' do
      expect(statuses.size).to eq 28
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
