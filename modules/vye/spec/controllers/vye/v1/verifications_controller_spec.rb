# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  let!(:current_user) { create(:user, :accountable) }

  before do
    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(Vye::V1::VerificationsController).to receive(:authorize).and_return(true)
  end

  describe '#create' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:future] }
    let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 2, 15) }
    let(:last_day_of_previous_month) { Date.new(2024, 2, 29) } # This is not used only for documentation
    let(:award_begin_date) { Date.new(2024, 3, 30) }
    let(:today) { Date.new(2024, 3, 31) } # This is not used only for documentation
    let(:award_end_date) { Date.new(2024, 4, 1) }
    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, cur_award_ind:) }
    let(:award_ids) { user_info.awards.pluck(:id) }
    let!(:params) { { award_ids: } }

    # rubocop:disable RSpec/SubjectStub
    before do
      allow(subject).to receive_messages(
        params:,
        current_user:,
        head: :no_content # We're testing the funtionality of the action, not the controller
      )

      subject.send(:load_user_info) # private method override
    end
    # rubocop:enable RSpec/SubjectStub

    it 'sets the transact date to the highest act_end of verifications' do
      subject.create
      highest_act_end = Vye::Verification.maximum(:act_end)

      Vye::Verification.all.find_each do |verification|
        expect(verification.transact_date).to eq(highest_act_end)
      end
    end

    it 'sets the cert_through date based on current date relative to award end dates' do
      # rubocop:disable Lint/ConstantDefinitionInBlock
      VerificationTest = Struct.new(:act_end)
      # rubocop:enable Lint/ConstantDefinitionInBlock
      award_dates = [
        Time.zone.parse('2024-08-10'),
        Time.zone.parse('2024-10-15'),
        Time.zone.parse('2024-12-15')
      ]

      test_verifications = award_dates.map { |date| VerificationTest.new(date) }

      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive(:pending_verifications).and_return(test_verifications)
      # rubocop:enable RSpec/SubjectStub

      Timecop.freeze(Time.zone.parse('2024-11-15')) do
        expect(subject.send(:cert_through_date).to_date).to eq(Date.new(2024, 10, 15))
      end

      # show last award day rather than last day of previous month when award has ended
      Timecop.freeze(Time.zone.parse('2024-12-15')) do
        expect(subject.send(:cert_through_date).to_date).to eq(Date.new(2024, 12, 15))
        expect(subject.send(:cert_through_date).to_date).not_to eq(Date.new(2024, 11, 30))
      end
    end
  end
end
