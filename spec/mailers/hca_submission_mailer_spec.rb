# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCASubmissionMailer, type: [:mailer] do
  let(:email) { 'foo@example.com' }
  let(:date) { '2016-05-25T04:59:39.345-05:00' }
  let(:confirmation_number) { 40_124_668_140 }

  subject do
    described_class.build(email, date, confirmation_number).deliver_now
  end

  describe '#build' do
    it 'should include all info' do
      expect(subject.subject).to eq("We've received your application")
      expect(subject.to).to eq(['foo@example.com'])
      expect(subject.body.raw_source).to include('Wednesday, May 25, 2016 at 04:59:39 AM -05:00')
      expect(subject.body.raw_source).to include(confirmation_number.to_s)
    end
  end
end
