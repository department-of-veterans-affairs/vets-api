# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::ServiceRecord do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:service_record) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :service_branch, :discharge_type, :highest_rank, :national_guard_state
    )

    expect(described_class.permitted_params).to include(date_range: Preneeds::DateRange.permitted_params)
  end

  describe 'when converting to eoas' do
    it 'produces an ordered hash' do
      expect(subject.as_eoas.keys).to eq(
        %i[branchOfService dischargeType enteredOnDutyDate highestRank nationalGuardState releaseFromDutyDate]
      )
    end

    it 'removes enteredOnDutyDate, releaseFromDutyDate, highestRank, and nationalGuardState if blank' do
      params[:national_guard_state] = ''
      params[:highest_rank] = ''
      params[:date_range] = { from: '', to: '' }

      expect(subject.as_eoas.keys).not_to include(
        :enteredOnDutyDate, :releaseFromDutyDate, :highestRank, :nationalGuardState
      )
    end
  end

  describe 'when converting to json' do
    # let(:params) { attributes_for :service_record, :for_json_comparison }

    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
