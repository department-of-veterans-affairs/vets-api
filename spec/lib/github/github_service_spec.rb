# frozen_string_literal: true
require 'rails_helper'
require 'github/github_service'

describe Github::GithubService do
  let(:feedback) { build :feedback }
  let(:feedback_with_email) { build :feedback, :email_provided }
  let(:feedback_email_in_body) { build :feedback, :sensitive_data_in_body }

  it 'makes a create_issue API call to Github' do
    expect_any_instance_of(Octokit::Client).to receive(:create_issue)
      .with(
        'department-of-veterans-affairs/vets.gov-team',
        feedback.description[0..40],
        feedback.description + "\n\nTarget Page: /example/page\nEmail of Author: NOT PROVIDED",
        assignee: 'va-bot', labels: 'User Feedback'
      )
    described_class.create_issue(feedback)
  end

  it 'obfuscates user email' do
    expect_any_instance_of(Octokit::Client).to receive(:create_issue)
      .with(
        'department-of-veterans-affairs/vets.gov-team',
        feedback.description[0..40] + ' - Response Requested',
        feedback.description + "\n\nTarget Page: /example/page\nEmail of Author: j**********",
        assignee: 'va-bot', labels: 'User Feedback'
      )
    described_class.create_issue(feedback_with_email)
  end

  it 'filters sensitive data included in the feedback description' do
    expected_title = 'My email is j**********.  Page was hard, '
    expected_description = 'My email is j**********.  Page was hard, here is my ssn 1**********.'

    expect_any_instance_of(Octokit::Client).to receive(:create_issue)
      .with(
        'department-of-veterans-affairs/vets.gov-team',
        expected_title,
        expected_description + "\n\nTarget Page: /example/page\nEmail of Author: NOT PROVIDED",
        assignee: 'va-bot', labels: 'User Feedback'
      )
    described_class.create_issue(feedback_email_in_body)
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
