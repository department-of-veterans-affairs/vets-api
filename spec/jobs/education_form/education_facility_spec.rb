require 'rails_helper'

RSpec.describe EducationForm::EducationFacility, type: :model do
  let(:education_benefits_claim) { build(:education_benefits_claim) }
  let(:record) do
    education_benefits_claim.open_struct_form
  end

  describe '#regional_office_for' do
    {
      eastern: ['VA', "Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"],
      southern: ['PR', "Southern Region\nVA Regional Office\nP.O. Box 100022\nDecatur, GA 30031-7022"],
      central: ['CO', "Central Region\nVA Regional Office\nP.O. Box 66830\nSt. Louis, MO 63166-6830"],
      western: ['AK', "Western Region\nVA Regional Office\nP.O. Box 8888\nMuskogee, OK 74402-8888"]
    }.each do |region, region_data|
      context "with an #{region} address" do
        before do
          new_form = education_benefits_claim.parsed_form
          new_form['school']['address']['state'] = region_data[0]
          education_benefits_claim.form = new_form.to_json
        end

        it 'should return the right address' do
          expect(described_class.regional_office_for(record)).to eq(region_data[1])
        end
      end
    end
  end
end
