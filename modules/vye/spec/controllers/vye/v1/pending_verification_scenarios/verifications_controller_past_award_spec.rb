# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  describe 'past award' do
    subject { described_class.new }

    let(:date_last_certified) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 31) }
    let(:run_date) { Date.new(2025, 4, 1) }

    ###########################################################
    # glossary
    ###########################################################
    # award begin date (abd)
    # date last certified (dlc)
    # award end date (aed)
    # last day of prior month (ldpm)
    # run date (rd)

    # One scenario results in a past award (no pending verification)
    # aed < dlc

    describe 'aed < dlc' do
      let(:award_begin_date) { Date.new(2025, 3, 1) }
      let(:award_end_date) { Date.new(2025, 3, 30) }

      it 'is a past award and does not create a pending verification' do
        expect(Vye::Verification.count).to eq(0)
      end
    end
  end
end
