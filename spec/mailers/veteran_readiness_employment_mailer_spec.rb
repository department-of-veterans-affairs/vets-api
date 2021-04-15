# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranReadinessEmploymentMailer, type: [:mailer] do
  include ActionView::Helpers::TranslationHelper
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:email_addr) { 'kcrawford@governmentcio.com' }
  let(:current_date) { Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y') }

  describe '#build' do
    it 'includes all info' do
      mailer = described_class.build(user, email_addr).deliver_now

      expect(mailer.subject).to eq('VR&E Counseling Request Confirmation')
      expect(mailer.to).to eq(['kcrawford@governmentcio.com'])
      expect(mailer.body.raw_source).to include(
        'Submitted Application',
        "Veteran's PID: #{user.participant_id}",
        'Type of Form Submitted: 28-1900',
        "Submitted Date: #{current_date}"
      )
    end
  end
end
