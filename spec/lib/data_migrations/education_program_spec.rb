# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::EducationProgram do
  describe '#migrate' do
    let!(:claim1) { create(:education_benefits_claim) }
    let!(:claim2) do
      create(:education_benefits_claim_with_custom_form,
        custom_form: {
          educationProgram: {
            name: 'foo'
          }
        }
      )
    end

    it 'should convert the claims' do
      DataMigrations::EducationProgram.migrate

      [claim1, claim2].each do |education_benefits_claim|
        education_benefits_claim.instance_variable_set(:@parsed_form, nil)
      end
      parsed_form = claim1.reload.parsed_form
      education_program = parsed_form['educationProgram']
      expect(education_program['name']).to eq('FakeData University')
      expect(education_program['address']).to eq(
        {"country"=>"USA", "state"=>"MD", "postalCode"=>"21231", "street"=>"111 Uni Drive", "city"=>"Baltimore"}
      )
      expect(education_program['educationType']).to eq('college')
      expect(parsed_form['school']).to eq(nil)
      expect(parsed_form['educationType']).to eq(nil)

      parsed_form = claim2.reload.parsed_form
      expect(parsed_form['educationProgram']['name']).to eq('foo')
      expect(parsed_form['school']).to eq(nil)
      expect(parsed_form['educationType']).to eq(nil)
    end
  end
end
