# frozen_string_literal: true

require 'rspec'

RSpec.describe 'Ask::Iris::Oracle::OracleForm' do
  context 'oracle form' do
    it 'read_value_for_fields' do
      first_name_field = Ask::Iris::Oracle::Field.new({
                                                        schemaKey: 'fullName.first',
                                                        fieldName: 'Incident.CustomFields.c.first_name',
                                                        fieldType: Ask::Iris::Oracle::FieldTypes::TextField
                                                      })

      form_data = {"fullName"=>{"first" => "Jane"}}

      return_value = Ask::Iris::Oracle::OracleForm.read_value_for_field(first_name_field, form_data)

      expect(return_value).to eql('Jane')
    end
  end
end
