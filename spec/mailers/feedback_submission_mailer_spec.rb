# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FeedbackSubmissionMailer, type: [:mailer] do
  let(:feedback) { build :feedback }
  let(:feedback_with_email) { build :feedback, :email_provided }
  let(:feedback_malicious) { build :feedback, :malicious_email }
  let(:github_url) { 'https://github.com/department-of-veterans-affairs/vets.gov-team/issues/4985' }
  let(:github_issue_number) { 4985 }

  subject do
    described_class.build(feedback, github_url, github_issue_number).deliver_now
  end

  describe '#build' do
    it 'should include all info' do
      expect(subject.subject).to include(github_issue_number.to_s)
      expect(subject.body.raw_source).to include(github_url)
      expect(subject.body.raw_source).to include(feedback.target_page)
      expect(subject.body.raw_source).to include(feedback.description)
    end

    context 'when malicious input injection is attempted' do
      subject do
        described_class.build(feedback_malicious, github_url, github_issue_number).deliver_now
      end
      it 'should treat malicious input as string literals' do
        expect(subject.body.raw_source).to include(feedback_malicious.owner_email)
      end
    end

    context 'when email is provided' do
      subject do
        described_class.build(feedback_with_email, github_url, github_issue_number).deliver_now
      end
      it 'should include email in body' do
        expect(subject.body.raw_source).to include(feedback_with_email.owner_email)
      end
      it 'should append the subject line' do
        expect(subject.subject).to include('- Response Requested')
      end
    end

    context 'when email is not provided' do
      it 'should have the proper subject' do
        expect(subject.subject).to eq("#{github_issue_number}: Vets.gov Feedback Received")
      end
    end

    context 'when issue number is not provided' do
      subject do
        described_class.build(feedback_with_email, github_url, nil).deliver_now
      end
      it 'puts -1 in the subject line' do
        expect(subject.subject).to eq('-1: Vets.gov Feedback Received - Response Requested')
      end
    end

    context 'when in staging' do
      before do
        allow(FeatureFlipper).to receive(:staging_email?).and_return(true)
      end
      it 'should have the proper recipients' do
        expect(subject.to).to eq(described_class::STAGING_RECIPIENTS)
      end
    end

    context 'when not in staging' do
      before do
        allow(FeatureFlipper).to receive(:staging_email?).and_return(false)
      end
      it 'should have the proper recipients' do
        expect(subject.to).to eq(['feedback@va.gov'])
      end
    end

    context 'when no github link is provided' do
      subject do
        described_class.build(feedback_with_email, nil, github_issue_number).deliver_now
      end
      it 'should display a warning in the email body' do
        expect(subject.body.raw_source).to include('Warning: No Github link present!')
      end
    end
  end
end
