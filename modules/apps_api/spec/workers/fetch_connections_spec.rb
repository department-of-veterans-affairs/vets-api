# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe AppsApi::FetchConnections, type: :worker do
  subject { described_class }

  let(:fetch_connections) { AppsApi::FetchConnections.new }
  let(:time) { (Time.zone.today + 1.hour).to_datetime }
  let(:scheduled_job) { described_class.perform_in(time, 'FetchConnections', true) }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'perform' do
    before do
      allow_any_instance_of(AppsApi::NotificationService).to receive(:handle_event)
        .with(any_args).and_return(1)
    end

    it 'calls handle_event twice' do
      expect_any_instance_of(AppsApi::NotificationService).to receive(:handle_event)
        .with('app.oauth2.as.consent.grant', 'fake_template_id').and_return(1)
      fetch_connections.perform
    end
  end
end
