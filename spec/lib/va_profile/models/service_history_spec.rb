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
    context 'when vet_status_titled_alerts is enabled' do
      before do
        Flipper.enable(:vet_status_titled_alerts)
      end

      after do
        Flipper.disable(:vet_status_titled_alerts)
      end

      it 'returns not eligible with service history missing characterOfDischargeCode' do
        eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

        expect(eligibility).to eq({ confirmed: false,
                                    message: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLED })
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

        expect(eligibility).to eq({ confirmed: false,
                                    message: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLED })
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
        expect(eligibility).to eq({ confirmed: false,
                                    message: VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLED })
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

        expect(eligibility).to eq({ confirmed: false,
                                    message: VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLED })
      end
    end

    context 'when vet_status_titled_alerts is disabled' do
      it 'returns not eligible with service history missing characterOfDischargeCode' do
        eligibility = VAProfile::Models::ServiceHistory.determine_eligibility([create_model(json)])

        expect(eligibility).to eq({ confirmed: false, message: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE })
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

        expect(eligibility).to eq({ confirmed: false, message: VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE })
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
        expect(eligibility).to eq({ confirmed: false, message: VeteranVerification::Constants::NOT_FOUND_MESSAGE })
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

        expect(eligibility).to eq({ confirmed: false, message: VeteranVerification::Constants::NOT_FOUND_MESSAGE })
      end
    end
  end

  def create_model(json)
    data = JSON.parse(json)
    episode_type = VAProfile::Models::ServiceHistory::MILITARY_SERVICE_EPISODE
    VAProfile::Models::ServiceHistory.build_from(data, episode_type)
  end
end
