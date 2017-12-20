# frozen_string_literal: true
require 'rails_helper'
require 'github/github_service'

describe Github::GithubService do
  let(:feedback) { build :feedback }
  let(:feedback_with_email) { build :feedback, :email_provided }

  it 'makes a create_issue API call to Github' do
    expect_any_instance_of(Octokit::Client).to receive(:create_issue)
      .with(
        'department-of-veterans-affairs/vets.gov-team',
        feedback.description[0..40],
        feedback.description + "\n\nTarget Page: /example/page\nEmail of Author: NOT PROVIDED",
        assignee: 'va-bot', labels: 'uservoice'
      )
    described_class.create_issue(feedback)
  end

  it 'obfuscates user email' do
    expect_any_instance_of(Octokit::Client).to receive(:create_issue)
      .with(
        'department-of-veterans-affairs/vets.gov-team',
        feedback.description[0..40] + ' - Response Requested',
        feedback.description + "\n\nTarget Page: /example/page\nEmail of Author: j**********",
        assignee: 'va-bot', labels: 'uservoice'
      )
    described_class.create_issue(feedback_with_email)
  end

  # To regenerate VCR: purposely set a bad password/API key for Octokit::Client
  auth_fail = { cassette_name: 'github/auth_fail' }
  context 'when Github API call returns an error', vcr: auth_fail do
    it 'logs an exception' do
      expect(described_class).to receive(:log_exception_to_sentry)
      described_class.create_issue(feedback)
    end
    it 'returns nil' do
      expect(described_class.create_issue(feedback)).to eq(nil)
    end
  end
end
