# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe IncomeLimits::StdIncomeThresholdImport, type: :worker do
  describe '#perform' do
    # rubocop:disable Layout/LineLength
    let(:csv_data) do
      %(ID,INCOME_THRESHOLD_YEAR,EXEMPT_AMOUNT,MEDICAL_EXPENSE_DEDUCTIBLE,CHILD_INCOME_EXCLUSION,DEPENDENT,ADD_DEPENDENT_THRESHOLD,PROPERTY_THRESHOLD,PENSION_THRESHOLD,PENSION_1_DEPENDENT,ADD_DEPENDENT_PENSION,NINETY_DAY_HOSPITAL_COPAY,ADD_90_DAY_HOSPITAL_COPAY,OUTPATIENT_BASIC_CARE_COPAY,OUTPATIENT_SPECIALTY_COPAY,THRESHOLD_EFFECTIVE_DATE,AID_AND_ATTENDANCE_THRESHOLD,OUTPATIENT_PREVENTIVE_COPAY,MEDICATION_COPAY,MEDICATIN_COPAY_ANNUAL_CAP,LTC_INPATIENT_COPAY,LTC_OUTPATIENT_COPAY,LTC_DOMICILIARY_COPAY,INPATIENT_PER_DIEM,DESCRIPTION,VERSION,CREATED,UPDATED,CREATED_BY,UPDATED_BY\n1,2023,1000,200,500,2,300,100000,15000,5000,2000,50,25,10,15,01/01/2023,300,5,5,1000,75,100,50,250,Description A,1,2/19/2010 8:36:52.057269 AM,3/19/2010 8:36:52.057269 AM,John,Sam)
    end
    # rubocop:enable Layout/LineLength

    before do
      allow_any_instance_of(IncomeLimits::StdIncomeThresholdImport).to receive(:fetch_csv_data).and_return(csv_data)
    end

    it 'populates income limits' do
      IncomeLimits::StdIncomeThresholdImport.new.perform

      expect(StdIncomeThreshold.find_by(income_threshold_year: 2023)).not_to be_nil
      expect(StdIncomeThreshold.find_by(exempt_amount: 1000)).not_to be_nil
    end

    it 'creates a new StdIncomeThreshold record' do
      expect do
        described_class.new.perform
      end.to change(StdIncomeThreshold, :count).by(1)
    end

    it 'sets the attributes correctly' do
      described_class.new.perform
      threshold = StdIncomeThreshold.last
      expect(threshold.income_threshold_year).to eq(2023)
      expect(threshold.pension_threshold).to eq(15_000)
      expect(threshold.pension_1_dependent).to eq(5000)
      expect(threshold.add_dependent_pension).to eq(2000)
    end
  end
end
