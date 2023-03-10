# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::StatusUpdatedJob, type: :job do
  let(:error_message) do
    'AppealsApi::StatusUpdated: Missing required keys, ' \
      '["status_event", "from", "to", "status_update_time", "statusable_id"]'
  end

  describe 'hlr_status_updated' do
    it 'errors if the keys needed are missing' do
      opts = {
        'status_event' => 'hlr_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now
      }

      expect(Rails.logger).to receive(:error).with error_message

      described_class.new.perform(opts)
    end

    it 'creates a status update' do
      opts = {
        'status_event' => 'hlr_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now,
        'statusable_id' => 'id_of_status'
      }

      expect { described_class.new.perform(opts) }.to change(
        AppealsApi::StatusUpdate,
        :count
      ).by(1)
    end
  end

  describe 'nod_status_updated' do
    it 'errors if the keys needed are missing' do
      opts = {
        'status_event' => 'nod_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now
      }

      expect(Rails.logger).to receive(:error).with error_message

      described_class.new.perform(opts)
    end

    it 'creates a status update' do
      opts = {
        'status_event' => 'nod_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now,
        'statusable_id' => 'id_of_status'
      }

      expect { described_class.new.perform(opts) }.to change(
        AppealsApi::StatusUpdate,
        :count
      ).by(1)
    end
  end

  describe 'sc_status_updated' do
    it 'errors if the keys needed are missing' do
      opts = {
        'status_event' => 'sc_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now
      }

      expect(Rails.logger).to receive(:error).with error_message

      described_class.new.perform(opts)
    end

    it 'creates a status update' do
      opts = {
        'status_event' => 'sc_status_updated',
        'from' => 'pending',
        'to' => 'submitted',
        'status_update_time' => Time.zone.now,
        'statusable_id' => 'id_of_status'
      }

      expect { described_class.new.perform(opts) }.to change(
        AppealsApi::StatusUpdate,
        :count
      ).by(1)
    end
  end
end
