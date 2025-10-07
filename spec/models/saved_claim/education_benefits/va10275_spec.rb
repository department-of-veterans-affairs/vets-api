# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10275 do
  let(:instance) { build(:va10275) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10275')

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'confirmation email for 10275' do
      it 'is skipped when feature flag is turned off' do
        allow(Flipper).to receive(:enabled?).with(:form22_10275_submission_email).and_return(false)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va10275)
        subject.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
        Flipper.enable(:form0994_confirmation_email)
      end

      it 'sends the email when feature flag is on' do
        allow(Flipper).to receive(:enabled?).with(:form22_10275_submission_email).and_return(true)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va10275)
        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'tbd@example.com',
          'form10275_submission_email_template_id',
          satisfy do |args|
            args[:header].include?('Springfield University') &&
            args[:header].include?('US123456') &&
            args[:locations].include?('Springfield Technical Institute') &&
            args[:locations].include?('US654321') &&
            args[:officials].include?('michael.brown@springfield.edu') &&
            args[:officials].include?('emily.johnson@springfield.edu') &&
            args[:signature].include?('Robert Smith')
          end
        )
      end
    end
  end
end
