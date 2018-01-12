# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Github::CreateIssueJob, type: :job do
  before(:each) do
    # clear and reload Github::CreateIssueJob class in order to test class
    # variable 'THROTTLE'
    Object.send(:remove_const, :Github)
  end
  context 'RAILS_ENV=production' do
    before do
      allow(Rails)
        .to(receive(:env))
        .and_return(ActiveSupport::StringInquirer.new('production'))
    end
    it 'does something' do
      expect { load 'app/workers/github/create_issue_job.rb' }.to raise_exception(NameError)
    end
  end

  context 'RAILS_ENV=development' do
    before do
      allow(Rails)
        .to(receive(:env))
        .and_return(ActiveSupport::StringInquirer.new('development'))
      load 'app/workers/github/create_issue_job.rb'
    end
    it 'should not use rate limiting' do
      expect(Github::CreateIssueJob::THROTTLE.class.to_s).to eq('Github::CreateIssueJob::NoThrottle')
    end
    it 'defines a "within_limit" method and yields' do
      expect(Github::CreateIssueJob::THROTTLE.within_limit { 'something' }).to eq('something')
    end
  end

  context 'sending more jobs than the rate limit' do
    before do
      load 'app/workers/github/create_issue_job.rb'
      module Sidekiq::Limiter
        class OverLimit < RuntimeError
        end
      end
    end

    it 'increments counter in statsd' do
      allow(Feedback)
        .to receive(:new)
        .and_raise(Sidekiq::Limiter::OverLimit)
      allow(subject)
        .to receive(:metric_name)
        .and_return('shared.sidekiq.default.Github_CreateIssueJob.rate_limited')

      metric = 'shared.sidekiq.default.Github_CreateIssueJob.rate_limited'
      expect { subject.perform({}) }.to raise_exception(Sidekiq::Limiter::OverLimit)
        .and trigger_statsd_increment(metric, times: 1, value: 1)
    end
  end
end
