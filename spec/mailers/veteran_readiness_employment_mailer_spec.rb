# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranReadinessEmploymentMailer, type: [:mailer] do
  include ActionView::Helpers::TranslationHelper
  let(:email_addr) { 'kcrawford@governmentcio.com' }
  let(:current_date) { Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y') }

  describe '#build' do
    subject { described_class.build(user, email_addr, routed_to_cmp).deliver_now }

    context 'routed_to_cmp is false' do
      let(:user) { FactoryBot.create(:evss_user, :loa3) }
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

    context 'routed_to_cmp is true' do
      let(:user) { create(:unauthorized_evss_user) }
      let(:routed_to_cmp) { true }

      it 'adds (routed to CMP)' do
        expect(subject.body.raw_source).to include('(routed to CMP)')
      end
    end
  end
end
