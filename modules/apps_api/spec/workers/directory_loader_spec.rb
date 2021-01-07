# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe AppsApi::DirectoryLoader, type: :worker do
  subject { described_class }

  let(:directory_loader) { AppsApi::DirectoryLoader.new }
  let(:time) { (Time.zone.today + 1.minute).to_datetime }
  let(:scheduled_job) { described_class.perform_in(time, 'LoadApplications', true) }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'testing worker' do
    it 'ActionItemWorker jobs are enqueued in the scheduled queue' do
      described_class.perform_async
      assert_equal 'default', described_class.queue
    end
    it 'goes into the jobs array for testing environment' do
      expect do
        described_class.perform_async
      end.to change(described_class.jobs, :size).by(1)
      described_class.new.perform
    end
  end
end
