# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidResearch::Volunteer::SubmissionMailer, type: :mailer do
  let(:recipient) { 'recipient@example.com' }
  let(:message)   { described_class.build(recipient) }

  describe '#build' do
    it 'sends to the specified email address' do
      expect(message.to).to eq([recipient])
    end

    it 'uses the signup subject' do
      expect(message.subject).to eq(described_class::SIGNUP_SUBJECT)
    end
  end
end
