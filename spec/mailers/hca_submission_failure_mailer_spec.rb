# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCASubmissionFailureMailer, type: [:mailer] do
  let(:email) { 'foo@example.com' }

  subject do
    described_class.build(email).deliver_now
  end

  describe '#build' do
    it 'should include all info' do
      expect(subject.subject).to eq("We didn't receive your application")
      expect(subject.to).to eq(['foo@example.com'])
      expect(subject.body.raw_source).to include(
        "We’re sorry. Your application for VA health care benefits didn’t go through, and you'll need to start over."
      )
    end
  end
end
