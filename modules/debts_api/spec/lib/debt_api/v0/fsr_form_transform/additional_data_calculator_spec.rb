# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/additional_data_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::AdditionalDataCalculator, type: :service do
  describe 'get_bankruptcy_data' do
    let(:form) { get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform') }

    it 'returns bankruptcy data' do
      service = described_class.new(form)

      expect(service.get_bankruptcy_data).to eq({
                                                  'hasBeenAdjudicatedBankrupt' => true,
                                                  'dateDischarged' => '02/2020',
                                                  'courtLocation' => 'fdas',
                                                  'docketNumber' => 'dfasa'
                                                })
    end

    it 'handles empty date for date discharged' do
      form['additional_data']['bankruptcy']['date_discharged'] = ''
      service = described_class.new(form)

      expect(service.get_bankruptcy_data['dateDischarged']).to eq('00/0000')
    end

    it 'handles bad date for date discharged' do
      form['additional_data']['bankruptcy']['date_discharged'] = 'this is not a date'
      expect(Rails.logger).to receive(:error).with('DebtsApi AdditionalDataCalculator#get_discharge_date: invalid date')
      expect(Rails.logger).to receive(:info).with(
        'DebtsApi AdditionalDataCalculator#get_discharge_date input: this is not a date'
      )
      service = described_class.new(form)

      expect(service.get_bankruptcy_data['dateDischarged']).to eq('00/0000')
    end

    it 'handles yyyy-mm-dd date for date discharged' do
      form['additional_data']['bankruptcy']['date_discharged'] = '2024-03-15'
      service = described_class.new(form)

      expect(service.get_bankruptcy_data['dateDischarged']).to eq('03/2024')
    end

    it 'handles yyyy-mm date for date discharged' do
      form['additional_data']['bankruptcy']['date_discharged'] = '2016-01'
      service = described_class.new(form)

      expect(service.get_bankruptcy_data['dateDischarged']).to eq('00/0000')
    end
  end
end
