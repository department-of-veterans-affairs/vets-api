# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Github::CreateIssueJob, type: :job do
  before do
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
  end
end
