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
    let(:award_begin_date) { Date.new(2024, 3, 30) }
    let(:award_end_date) { Date.new(2024, 4, 1) }
    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, cur_award_ind:) }
    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    # rubocop:disable RSpec/SubjectStub
    before do
      allow(subject).to receive_messages(
        params:,
        current_user:,
        head: :no_content
      )
      subject.send(:load_user_info)
    end
    # rubocop:enable RSpec/SubjectStub

    describe 'cert_through_date calculation' do
      let!(:verification1) { create(:vye_verification, act_end: Date.new(2024, 4, 1), award: award) }
      let!(:verification2) { create(:vye_verification, act_end: Date.new(2024, 5, 1), award: award2) }

      before do
        allow(subject).to receive(:pending_verifications).and_return([verification1, verification2])
      end

      it 'returns verification-specific act_end when current date is on or after that verification act_end' do
        Timecop.freeze(Date.new(2024, 4, 1)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(verification1.act_end.to_date)
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 3, 31))
        end
      end

      it 'returns end of current month when on last day of month' do
        Timecop.freeze(Date.new(2024, 3, 31)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(Date.new(2024, 3, 31))
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 3, 31))
        end
      end

      it 'returns end of previous month for mid-month dates' do
        Timecop.freeze(Date.new(2024, 3, 15)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(Date.new(2024, 2, 29))
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 2, 29))
        end
      end
    end

    describe 'verification updates' do
      it 'sets different transact_dates based on each verification act_end' do
        verification1 = create(:vye_verification, act_end: Date.new(2024, 4, 1), award: award)
        verification2 = create(:vye_verification, act_end: Date.new(2024, 5, 1), award: award2)
        allow(subject).to receive(:pending_verifications).and_return([verification1, verification2])

        Timecop.freeze(Date.new(2024, 4, 15)) do
          subject.create
          expect(verification1.reload.transact_date.to_date).to eq(verification1.act_end.to_date)
          expect(verification2.reload.transact_date.to_date).to eq(Date.new(2024, 3, 31))
        end
      end
    end
  end
end