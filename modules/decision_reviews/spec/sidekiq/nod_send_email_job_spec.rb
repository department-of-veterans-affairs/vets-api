# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReviews::NodSendEmailJob, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  let(:service) { instance_double(VaNotify::Service) }

  let(:email_address) { Faker::Internet.email }
  let(:template_id) { Faker::Internet.uuid }
  let(:personalisation) { { 'full_name' => Faker::Name.name } }
  let(:line_num) { 5 }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(service)
  end

  describe 'perform' do
    context 'with correct job parameters' do
      it 'sends email using VANotify service' do
        expect(service).to receive(:send_email).with({ email_address:, template_id:, personalisation: })

        subject.perform_async(email_address, template_id, personalisation, line_num)
      end
    end

    context 'when an exception is thrown while sending email' do
      let(:error_message) { 'Failed to send email' }

      before do
        allow(service).to receive(:send_email).and_raise(StandardError, error_message)
      end

      it 'rescues and logs the exception message with the line number' do
        job = subject.new
        expect(job).to receive(:log_formatted) do |args|
          expect(args[:params][:line_num]).to eq line_num
          expect(args[:params][:exception_message]).to eq error_message
        end

        expect { job.perform(email_address, template_id, personalisation, line_num) }.not_to raise_exception
      end
    end
  end
end
