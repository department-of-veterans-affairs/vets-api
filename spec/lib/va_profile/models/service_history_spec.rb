# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/service_history'

describe VAProfile::Models::ServiceHistory do
  let(:model) { VAProfile::Models::ServiceHistory.new }
  let(:json) do
    '{
      "branch_of_service_text": "National Guard",
      "period_of_service_begin_date": "2010-01-01",
      "period_of_service_end_date": "2015-12-31",
      "period_of_service_type_code": "N"
    }'
  end

  context 'when service history json is present' do
    it 'returns a service_history model' do
      data = JSON.parse(json)
      model = VAProfile::Models::ServiceHistory.build_from(data)

      expect(model).not_to be_nil
      expect(model.branch_of_service).to eq('National Guard')
      expect(model.begin_date).to eq('2010-01-01')
      expect(model.end_date).to eq('2015-12-31')
      expect(model.personnel_category_type_code).to eq('N')
    end
  end

  context 'when service history json is nil' do
    it 'returns nil' do
      model = VAProfile::Models::ServiceHistory.build_from(nil)

      expect(model).to be_nil
    end
  end
end
