# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe CovidResearch::Volunteer::SubmissionMailer, type: :mailer do
  let(:recipient) { 'recipient@example.com' }
  let(:intake_template_name) { 'signup_confirmation.html.erb' }
  let(:update_template_name) { 'update_confirmation.html.erb' }

  let(:intake_message)   { described_class.build(recipient, intake_template_name) }
  let(:update_message)   { described_class.build(recipient, update_template_name) }

  describe '#build email for initial form' do
    it 'sends to the specified email address' do
      expect(intake_message.to).to eq([recipient])
    end

    it 'uses the signup subject' do
      expect(intake_message.subject).to eq(described_class::SIGNUP_SUBJECT)
    end

    it 'uses the correct template for intake' do
      expect(intake_message.body).to include('added you to our VA coronavirus research volunteer list')
    end
  end

  describe '#build email for update form' do
    it 'sends to the specified email address' do
      expect(update_message.to).to eq([recipient])
    end

    it 'uses the signup subject' do
      expect(update_message.subject).to eq(described_class::SIGNUP_SUBJECT)
    end

    it 'uses the correct template for intake' do
      expect(update_message.body).to include('Thank you for submitting the updated information')
    end
  end
end
