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
      model = create_model(json)

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

  describe '#determing_eligibility' do
    let(:not_eligible_message) do
      [
        'Our records show that you’re not eligible for a Veteran status card. To get a Veteran status card, you must ' \
        'have received an honorable discharge for at least one period of service.',
        'If you think your discharge status is incorrect, call the Defense Manpower Data Center at 800-538-9552 ' \
        '(TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
      ]
    end
    let(:problem_message) do
      [
        'We’re sorry. There’s a problem with your discharge status records. We can’t provide a Veteran status card ' \
        'for you right now.',
        'To fix the problem with your records, call the Defense Manpower Data Center at 800-538-9552 (TTY: 711). ' \
        'They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
      ]
    end

    it 'returns not eligible with service history missing characterOfDischargeCode' do
      eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

      expect(eligibility).to eq({ confirmed: false, message: not_eligible_message })
    end

    it 'returns not eligible with dishonorable service history' do
      json = '{
        "branch_of_service_text": "National Guard",
        "period_of_service_begin_date": "2010-01-01",
        "period_of_service_end_date": "2015-12-31",
        "period_of_service_type_code": "N",
        "period_of_service_type_text": "National Guard member",
        "character_of_discharge_code":"D"
      }'
      eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

      expect(eligibility).to eq({ confirmed: false, message: not_eligible_message })
    end

    it 'returns eligible with honorable service history' do
      json = '{
        "branch_of_service_text": "National Guard",
        "period_of_service_begin_date": "2010-01-01",
        "period_of_service_end_date": "2015-12-31",
        "period_of_service_type_code": "N",
        "period_of_service_type_text": "National Guard member",
        "character_of_discharge_code":"A"
      }'
      eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

      expect(eligibility).to eq({ confirmed: true, message: [] })
    end

    it 'returns problem message with no service history' do
      eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([])
      expect(eligibility).to eq({ confirmed: false, message: problem_message })
    end

    it 'returns problem message with service history containing unknown discharge code' do
      json = '{
        "branch_of_service_text": "National Guard",
        "period_of_service_begin_date": "2010-01-01",
        "period_of_service_end_date": "2015-12-31",
        "period_of_service_type_code": "N",
        "period_of_service_type_text": "National Guard member",
        "character_of_discharge_code":"Z"
      }'
      eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

      expect(eligibility).to eq({ confirmed: false, message: problem_message })
    end
  end

  def create_model(json)
    data = JSON.parse(json)
    episode_type = VAProfile::Models::ServiceHistory::MILITARY_SERVICE_EPISODE
    VAProfile::Models::ServiceHistory.build_from(data, episode_type)
  end
end
