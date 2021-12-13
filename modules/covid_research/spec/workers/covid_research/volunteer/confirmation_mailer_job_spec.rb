# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../../app/workers/covid_research/volunteer/confirmation_mailer_job'

RSpec.describe CovidResearch::Volunteer::ConfirmationMailerJob do
  subject         { described_class.new }

  let(:recipient) { 'test@example.com' }
  let(:intake_template_name) { 'signup_confirmation.html.erb' }
  let(:update_template_name) { 'update_confirmation.html.erb' }

  let(:dummy) { double('Mail::Message') }

  describe '#perform' do
    it 'builds an email to the given email' do
      allow(dummy).to receive(:deliver)
      expect(CovidResearch::Volunteer::SubmissionMailer).to receive(:build).with(recipient,
                                                                                 intake_template_name).and_return(dummy)

      subject.perform(recipient, intake_template_name)
    end

    it 'delivers the email' do
      allow(CovidResearch::Volunteer::SubmissionMailer).to receive(:build).and_return(dummy)
      expect(dummy).to receive(:deliver)

      subject.perform(recipient, intake_template_name)
    end
  end
end
