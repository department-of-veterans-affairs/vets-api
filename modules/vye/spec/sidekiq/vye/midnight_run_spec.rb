# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun, type: :worker do
  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  it 'enqueues child jobs' do
    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::MidnightRun::IngressBdn).to have_enqueued_sidekiq_job
  end

  context 'logging' do
    before do
      allow(Vye::MidnightRun::IngressBdn).to receive(:perform_async).and_return(nil)
    end

    it 'logs info' do
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun starting')
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun finished')

      # The perform_async method in Sidekiq is designed to enqueue a job, not to execute it immediately.
      # In the RSpec test environment, the job isn't executed unless you explicitly call perform or
      # configure Sidekiq for inline execution during the test.
      #
      # If you want to test perform_async directly in the future, you can configure Sidekiq to execute
      # jobs immediately in your test setup. Add the following to your spec_helper.rb or rails_helper.rb:
      # require 'sidekiq/testing'
      # Sidekiq::Testing.inline!
      #
      # As these are global changes and impact every team, I'm reluctant to implement w/out consulting platform
      # support.
      # Todo: followup w/platform about this
      Vye::MidnightRun.new.perform
    end
  end

  context 'with disabled flipper set' do
    before do
      allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(true)
    end

    it 'does not do any processing' do
      expect(Vye::MidnightRun::IngressBdn).not_to receive(:perform_async)
      described_class.new.perform
    end
  end
end
