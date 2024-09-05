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
      "period_of_service_type_code": "N",
      "period_of_service_type_text": "National Guard member"
    }'
  end

  context 'when service history json is present' do
    it 'returns a service_history model' do
      data = JSON.parse(json)
      episode_type = VAProfile::Models::ServiceHistory::MILITARY_SERVICE_EPISODE
      model = VAProfile::Models::ServiceHistory.build_from(data, episode_type)

      expect(model).not_to be_nil
      expect(model.branch_of_service).to eq('National Guard')
      expect(model.begin_date).to eq('2010-01-01')
      expect(model.end_date).to eq('2015-12-31')
      expect(model.period_of_service_type_code).to eq('N')
      expect(model.period_of_service_type_text).to eq('National Guard member')
      expect(model.personnel_category_type_code).to eq('N')
      expect(model.personnel_category_type_text).to eq('National Guard member')
    end
  end

  context 'when service history json is nil' do
    it 'returns nil' do
      episode_type = VAProfile::Models::ServiceHistory::MILITARY_SERVICE_EPISODE
      model = VAProfile::Models::ServiceHistory.build_from(nil, episode_type)
      expect(model).to be_nil
    end
  end

  context 'when episode type is nil' do
    it 'returns nil' do
      data = JSON.parse(json)
      model = VAProfile::Models::ServiceHistory.build_from(data, nil)
      expect(model).to be_nil
    end
  end
end
