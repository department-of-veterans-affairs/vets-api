# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FeedbackSubmissionMailer, type: [:mailer] do
  let(:feedback) { build :feedback }
  let(:feedback_with_email) { build :feedback, :email_provided }
  let(:github_url) { 'https://github.com/department-of-veterans-affairs/vets.gov-team/issues/4985' }

  subject do
    described_class.build(feedback, github_url).deliver_now
  end

  describe '#build' do
    it 'should include all info' do
      expect(subject.body.raw_source).to include(github_url)
      expect(subject.body.raw_source).to include(feedback.target_page)
      expect(subject.body.raw_source).to include(feedback.description)
    end

    context 'when email is provided' do
      subject do
        described_class.build(feedback_with_email, github_url).deliver_now
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
        expect(subject.subject).to eq('Vets.gov Feedback Received')
      end
    end

    context 'when in staging' do
      before do
        allow(FeatureFlipper).to receive(:staging_email?).and_return(true)
      end
      it 'should have the proper recipients' do
        expect(subject.to).to eq(['bill.ryan@adhocteam.us'])
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
  end
end