# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::ServiceRecord do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :service_record }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(xml_dates(params))
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :branch_of_service, :discharge_type, :entered_on_duty_date,
      :highest_rank, :national_guard_state, :release_from_duty_date
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq(
      [
        :branchOfService, :dischargeType, :enteredOnDutyDate,
        :highestRank, :nationalGuardState, :releaseFromDutyDate
      ]
    )
  end
end
