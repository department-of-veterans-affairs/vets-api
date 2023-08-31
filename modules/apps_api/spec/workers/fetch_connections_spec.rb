# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe AppsApi::FetchConnections, type: :worker do
  subject { described_class }

  let(:fetch_connections) { AppsApi::FetchConnections.new }
  let(:time) { (Time.zone.today + 1.hour).to_datetime }
  let(:scheduled_job) { described_class.perform_in(time, 'FetchConnections', true) }

  let(:notification_client) { double('Notifications::Client') }

  before do
    # in order to not get an error of 'nil is not a valid uuid' when the
    # notification_client tries in to initialize and looks for valid
    # api_keys in config.api_key && config.client_url
    # lib/va_notify/configuration.rb#initialize contains:
    # @notify_client ||= Notifications::Client.new(api_key, client_url)
    allow(Notifications::Client).to receive(:new).and_return(notification_client)
    allow(notification_client).to receive(:send_email)
    Sidekiq::Worker.clear_all
  end

  describe 'perform' do
    before do
      allow_any_instance_of(AppsApi::NotificationService).to receive(:handle_event)
        .with(any_args).and_return(1)
    end

    xit 'calls handle_event twice' do
      expect_any_instance_of(AppsApi::NotificationService).to receive(:handle_event)
        .with('app.oauth2.as.consent.revoke', 'fake_template_id').and_return(1)
      fetch_connections.perform
    end

    xit 'goes into the jobs array for testing environment' do
      expect do
        described_class.perform_async
      end.to change(described_class.jobs, :size).by(1)
      described_class.new.perform
    end
  end
end
