# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/ivc_champva/monitor'

RSpec.describe IvcChampva::Monitor do
  let(:monitor) { described_class.new }

  before do
    allow(Flipper).to receive(:enabled?)
      .with(:champva_enhanced_monitor_logging, @current_user)
      .and_return(true)
  end

  context 'with params supplied' do
    describe '#track_update_status' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678',
          status: 'Processed'
        }

        expect(monitor).to receive(:track_update_status).with(
          payload[:form_uuid], payload[:status]
        )
        monitor.track_update_status(payload[:form_uuid], payload[:status])
      end
    end

    describe '#track_insert_form' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678',
          form_id: 'vha_10_10d'
        }

        expect(monitor).to receive(:track_insert_form).with(
          payload[:form_uuid], payload[:form_id]
        )
        monitor.track_insert_form(payload[:form_uuid], payload[:form_id])
      end
    end

    describe '#track_missing_status_email_sent' do
      it 'logs sidekiq success' do
        payload = {
          form_id: 'vha_10_10d'
        }

        expect(monitor).to receive(:track_missing_status_email_sent).with(
          payload[:form_id]
        )
        monitor.track_missing_status_email_sent(payload[:form_id])
      end
    end
  end
end
