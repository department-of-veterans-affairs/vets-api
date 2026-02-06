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
      subject { create(:va10275) }

      it 'sends the email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'form_10275@example.com',
          'form10275_submission_email_template_id',
          satisfy do |args|
            args[:submission_id] == subject.id &&
            args[:agreement_type] == 'New commitment' &&
            args[:institution_details].include?('Springfield University') &&
            args[:institution_details].include?('US123456') &&
            args[:additional_locations].include?('Springfield Technical Institute') &&
            args[:additional_locations].include?('US654321') &&
            args[:points_of_contact].include?('michael.brown@springfield.edu') &&
            args[:points_of_contact].include?('emily.johnson@springfield.edu') &&
            args[:submission_information].include?('Robert Smith')
          end,
          'fake_secret',
          anything
        )
      end
    end
  end
end
