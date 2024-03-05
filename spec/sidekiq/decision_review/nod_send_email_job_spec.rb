# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::NodSendEmailJob, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  let(:email) { Faker::Internet.email }
  let(:template_id) { Faker::Internet.uuid }
  let(:service) { instance_double(VaNotify::Service) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(service)
  end

  describe 'perform' do
    context 'with correct job parameters' do
      it 'sends email using VANotify service' do
        expect(service).to receive(:send_email).with({ email_address: email, template_id: })

        subject.perform_async(email, template_id, 1)
      end
    end

    context 'when an exception is thrown while sending email' do
      let(:line) { 5 }
      let(:error_message) { 'Failed to send email' }

      before do
        allow(service).to receive(:send_email).and_raise(StandardError, error_message)
      end

      it 'rescues and logs the exception message and line number' do
        job = subject.new
        expect(job).to receive(:log_formatted) do |args|
          expect(args[:params][:line]).to eq line
          expect(args[:params][:exception_message]).to eq error_message
        end

        expect { job.perform(email, template_id, line) }.not_to raise_exception
      end
    end
  end
end
