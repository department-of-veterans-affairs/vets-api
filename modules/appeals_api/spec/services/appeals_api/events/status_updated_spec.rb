# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module Events
    RSpec.describe StatusUpdated do
      describe 'hlr_status_updated' do
        it 'errors if the keys needed are missing' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).hlr_status_updated }.to raise_error(InvalidKeys)
        end

        it 'creates a status update' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now,
            'statusable_id' => 'id_of_status'
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).hlr_status_updated }.to change(
            AppealsApi::StatusUpdate,
            :count
          ).by(1)
        end
      end

      describe 'nod_status_updated' do
        it 'errors if the keys needed are missing' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).nod_status_updated }.to raise_error(InvalidKeys)
        end

        it 'creates a status update' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now,
            'statusable_id' => 'id_of_status'
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).nod_status_updated }.to change(
            AppealsApi::StatusUpdate,
            :count
          ).by(1)
        end
      end

      describe 'sc_status_updated' do
        it 'errors if the keys needed are missing' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).sc_status_updated }.to raise_error(InvalidKeys)
        end

        it 'creates a status update' do
          opts = {
            'from' => 'pending',
            'to' => 'submitted',
            'status_update_time' => Time.zone.now,
            'statusable_id' => 'id_of_status'
          }

          expect { AppealsApi::Events::StatusUpdated.new(opts).sc_status_updated }.to change(
            AppealsApi::StatusUpdate,
            :count
          ).by(1)
        end
      end
    end
  end
end
