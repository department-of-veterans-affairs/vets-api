# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::EducationFacility do
  let(:education_benefits_claim) { build(:education_benefits_claim) }

  describe '#regional_office_for' do
    {
      eastern: ['VA', "Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"],
      # rubocop:disable Metrics/LineLength
      central: ['CO', "Central Region\nVA Regional Office\n9770 Page Avenue\nSuite 101 Education\nSt. Louis, MO 63132-1502"],
      # rubocop:enable Metrics/LineLength
      western: ['AK', "Western Region\nVA Regional Office\nP.O. Box 8888\nMuskogee, OK 74402-8888"]
    }.each do |region, region_data|
      context "with a #{region} address" do
        before do
          new_form = education_benefits_claim.parsed_form
          new_form['school']['address']['state'] = region_data[0]
          education_benefits_claim.form = new_form.to_json
        end

        it 'should return the right address' do
          expect(described_class.regional_office_for(education_benefits_claim)).to eq(region_data[1])
        end
      end
    end
  end
end
