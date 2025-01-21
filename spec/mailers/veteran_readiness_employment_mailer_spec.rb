# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranReadinessEmploymentMailer, type: [:mailer] do
  include ActionView::Helpers::TranslationHelper
  let(:email_addr) { 'kcrawford@governmentcio.com' }
  let(:current_date) { Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y') }

  describe '#build' do
    subject { described_class.build(user.participant_id, email_addr, routed_to_cmp).deliver_now }

    context 'user is loa3 and has participant id' do
      let(:user) { create(:evss_user, :loa3) }

      context 'PDF is uploaded to VBMS' do
        let(:routed_to_cmp) { false }

        it 'includes all info' do
          expect(subject.subject).to eq('VR&E Counseling Request Confirmation')
          expect(subject.to).to eq(['kcrawford@governmentcio.com'])
          expect(subject.body.raw_source).to include(
            'Submitted Application',
            "Veteran's PID: #{user.participant_id}",
            'Type of Form Submitted: 28-1900',
            "Submitted Date: #{current_date}"
          )
        end
      end

      context 'PDF is not uploaded to VBMS because it is down' do
        let(:routed_to_cmp) { true }

        it 'builds email correctly' do
          expect(subject.subject).to eq('VR&E Counseling Request Confirmation')
          expect(subject.to).to eq(['kcrawford@governmentcio.com'])
          expect(subject.body.raw_source).to include(
            'Submitted Application via VA.gov was not successful.',
            'Application routed to the Centralized Mail Portal',
            "Veteran's PID: #{user.participant_id}",
            'Type of Form Submitted: 28-1900',
            "Submitted Date: #{current_date}"
          )
        end
      end
    end

    context 'user has no participant id' do
      let(:user) { create(:unauthorized_evss_user) }

      context 'PDF is uploaded to Central Mail' do
        let(:routed_to_cmp) { true }

        it 'includes all info' do
          expect(subject.subject).to eq('VR&E Counseling Request Confirmation')
          expect(subject.to).to eq(['kcrawford@governmentcio.com'])
          expect(subject.body.raw_source).to include(
            'Submitted Application via VA.gov was not successful.',
            'Application routed to the Centralized Mail Portal',
            "Veteran's PID:",
            'Type of Form Submitted: 28-1900',
            "Submitted Date: #{current_date}"
          )
        end
      end
    end
  end
end
