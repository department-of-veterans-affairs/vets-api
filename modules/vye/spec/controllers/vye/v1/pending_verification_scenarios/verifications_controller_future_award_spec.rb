# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'
  before do
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  describe 'future award' do
    subject { described_class.new }

    let(:date_last_certified) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 31) }
    let(:run_date) { Date.new(2025, 4, 15) }

    ###########################################################
    # glossary
    ###########################################################
    # award begin date (abd)
    # date last certified (dlc)
    # award end date (aed)
    # last day of prior month (ldpm)
    # run date (rd)

    # Four scenarios result in future awards (no pending verification)
    # 1) rd   <  abd
    # 2) dlc  <  ldpm <  abd <= rd < aed
    # 3) ldpm <  abd  <= dlc <  rd < aed
    # 4) ldpm <= dlc  <  abd <=	rd < aed

    describe 'rd < abd' do
      let(:award_begin_date) { Date.new(2025, 4, 16) }
      let(:award_end_date) { Date.new(2025, 4, 30) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'flags as a future award' do
        expect(Vye::Verification.count).to eq(0)
      end
    end

    describe 'dlc < ldpm < abd <= rd < aed' do
      let(:date_last_certified) { Date.new(2025, 3, 30) }
      let(:award_begin_date) { Date.new(2025, 4, 1) }
      let(:award_end_date) { Date.new(2025, 4, 30) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'flags as a future award' do
        expect(Vye::Verification.count).to eq(0)
      end
    end

    describe 'dlc < ldpm < abd = rd < aed' do
      let(:date_last_certified) { Date.new(2025, 3, 30) }
      let(:award_begin_date) { Date.new(2025, 4, 15) }
      let(:award_end_date) { Date.new(2025, 4, 30) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'flags as a future award' do
        expect(Vye::Verification.count).to eq(0)
      end
    end

    describe 'ldpm <= dlc < abd < rd < aed' do
      let(:award_begin_date) { Date.new(2025, 4, 1) }
      let(:award_end_date) { Date.new(2025, 4, 30) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create an eom pending verification' do
        expect(Vye::Verification.count).to eq(0)
      end
    end

    describe 'ldpm <= dlc < abd = rd < aed' do
      let(:award_begin_date) { Date.new(2025, 4, 15) }
      let(:award_end_date) { Date.new(2025, 4, 30) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create an eom pending verification' do
        expect(Vye::Verification.count).to eq(0)
      end
    end
  end
end
