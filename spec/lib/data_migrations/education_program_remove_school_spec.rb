# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::EducationProgramRemoveSchool do
  context 'with unmigrated records' do
    before do
      create(:va1990)
    end

    it 'should raise error' do
      expect { described_class.run }.to raise_error(RuntimeError)
    end
  end

  context 'with migrated records' do
    let!(:va1990) do
      create(
        :va1990_with_custom_form,
        custom_form: {
          educationProgram: {
            name: 'FakeData University',
            address: {
              country: 'USA',
              state: 'MD',
              postalCode: '21231',
              street: '111 Uni Drive',
              city: 'Baltimore'
            },
            educationType: 'college'
          }
        }
      )
    end

    it 'should migrate the fields' do
      described_class.run
      va1990.reload.instance_variable_set(:@parsed_form, nil)
      parsed_form = va1990.parsed_form

      expect(parsed_form['school']).to eq(nil)
      expect(parsed_form['educationType']).to eq(nil)
    end
  end
end
