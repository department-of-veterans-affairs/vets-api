# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::EducationProgram do
  describe '#migrate' do
    let!(:claim1) { create(:education_benefits_claim) }
    let!(:claim2) do
      create(
        :education_benefits_claim_with_custom_form,
        custom_form: {
          educationProgram: {
            name: 'foo'
          }
        }
      )
    end
    let!(:claim3) { create(:education_benefits_claim) }

    before do
      claim3.parsed_form.delete('educationType')
      claim3.form = claim3.parsed_form.to_json
      claim3.instance_variable_set(:@parsed_form, nil)
      claim3.save!
    end

    it 'should convert the claims' do
      DataMigrations::EducationProgram.migrate

      [claim1, claim2, claim3].each do |education_benefits_claim|
        education_benefits_claim.instance_variable_set(:@parsed_form, nil)
      end
      parsed_form = claim1.reload.parsed_form
      education_program = parsed_form['educationProgram']
      expect(education_program['name']).to eq('FakeData University')
      expect(education_program['address']).to eq(
        'country' => 'USA', 'state' => 'MD', 'postalCode' => '21231', 'street' => '111 Uni Drive', 'city' => 'Baltimore'
      )
      expect(education_program['educationType']).to eq('college')

      parsed_form = claim2.reload.parsed_form
      expect(parsed_form['educationProgram']['name']).to eq('foo')

      parsed_form = claim3.reload.parsed_form
      expect(parsed_form['educationProgram']['name']).to eq('FakeData University')
      expect(parsed_form['educationProgram']['educationType']).to eq(nil)
    end
  end
end
