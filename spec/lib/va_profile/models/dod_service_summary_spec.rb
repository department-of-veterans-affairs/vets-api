# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/dod_service_summary'

describe VAProfile::Models::DodServiceSummary do
  let(:model) { VAProfile::Models::DodServiceSummary.new }

  describe 'attributes' do
    it 'has the correct attributes' do
      model.dod_service_summary_code = 'V'
      model.calculation_model_version = '1.0'
      model.effective_start_date = '2020-01-01'

      expect(model.dod_service_summary_code).to eq('V')
      expect(model.calculation_model_version).to eq('1.0')
      expect(model.effective_start_date).to eq('2020-01-01')
    end
  end

  describe '.in_json' do
    it 'returns the correct bioPath' do
      json = JSON.parse(VAProfile::Models::DodServiceSummary.in_json)

      expect(json['bios']).to be_an(Array)
      expect(json['bios'].first['bioPath']).to eq('militaryPerson.militarySummary.customerType.dodServiceSummary')
    end
  end
end
