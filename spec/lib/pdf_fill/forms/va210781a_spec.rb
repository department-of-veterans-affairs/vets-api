# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

def basic_class
  PdfFill::Forms::Va210781a.new({})
end

describe PdfFill::Forms::Va210781a do
  let(:form_data) do
    {}
  end
  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end
  describe '#merge_fields' do
    it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21-0781a/simple')).merge_fields).to eq(
        get_fixture('pdf_fill/21-0781a/merge_fields')
      )
    end
  end

  describe '#combine_source_name_address' do
    it 'should expand sources correctly' do
      incident = {
        'sources' => [{
          'name' => 'Testy T Testerson',
          'address' => {
            'addressLine1' => '123 Main Street',
            'addressLine2' => '1B',
            'city' => 'Baltimore',
            'state' => 'MD',
            'country' => 'USA',
            'zipCode' => '21200-1111'
          }
        }]
      }

      expect(new_form_class.send(:combine_source_name_address, incident)).to eq(
        'combinedName0' => 'Testy T Testerson',
        'combinedAddress0' => '123 Main Street, 1B, Baltimore, MD, 21200-1111, USA'
      )
    end

    it 'should expand multiple sources correctly' do
      incident = {
        'sources' => [
          {
            'name' => 'Testy T Testerson',
            'address' => {
              'addressLine1' => '123 Main Street',
              'addressLine2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'zipCode' => '21200-1111'
            }
          },
          {
            'name' => 'Besty B Besterson',
            'address' => {
              'addressLine1' => '456 Main Street',
              'addressLine2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'zipCode' => '21200-1111'
            }
          }
        ]
      }

      expect(new_form_class.send(:combine_source_name_address, incident)).to eq(
        'combinedName0' => 'Testy T Testerson',
        'combinedAddress0' => '123 Main Street, 1B, Baltimore, MD, 21200-1111, USA',
        'combinedName1' => 'Besty B Besterson',
        'combinedAddress1' => '456 Main Street, 1B, Baltimore, MD, 21200-1111, USA'
      )
    end

    it 'should handle sources being empty correctly' do
      incident = {}

      expect(new_form_class.send(:combine_source_name_address, incident)).to be_nil
    end
  end

  describe '#expand_other_information' do
    let(:form_data) do
      {
        'otherInformation' => [
          'Other information text',
          'Category - Behavior Change A',
          'Category - Behavior Change B'
        ]
      }
    end

    it 'should expand other information correctly' do
      new_form_class.send(:expand_other_information)
      expect(
        JSON.parse(class_form_data.to_json)
      ).to eq(
        'otherInformation' => [
          { 'value' => 'Other information text' },
          { 'value' => 'Category - Behavior Change A' },
          { 'value' => 'Category - Behavior Change B' }
        ]
      )
    end
  end

  describe '#format_incident_overflow' do
    it 'incident information should handle no data' do
      expect(new_form_class.send(:format_incident_overflow, {}, 0)).to be_nil
    end
  end
end
