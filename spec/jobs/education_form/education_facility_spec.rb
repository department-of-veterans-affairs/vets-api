require 'rails_helper'

RSpec.describe EducationForm::EducationFacility, type: :model do
  let(:education_benefits_claim) { build(:education_benefits_claim) }
  let(:record) do
    education_benefits_claim.open_struct_form
  end

  describe '#regional_office_for' do
    context 'with an eastern address' do
      before do
        new_form = education_benefits_claim.parsed_form
        new_form['school']['address']['state'] = 'VA'
        education_benefits_claim.form = new_form.to_json
      end

      it 'should return the right address' do
        expect(described_class.regional_office_for(record)).to eq("Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616")
      end
    end
  end
end
