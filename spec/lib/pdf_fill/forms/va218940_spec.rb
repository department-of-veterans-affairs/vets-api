# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

def basic_class
  PdfFill::Forms::Va218940.new({})
end

describe PdfFill::Forms::Va218940 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  # describe '#merge_fields' do
  #   it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
  #     expect(described_class.new(get_fixture('pdf_fill/21-8940/kitchen_sink')).merge_fields).to eq(
  #       get_fixture('pdf_fill/21-8940/merge_fields')
  #     )
  #   end
  # end

  describe '#expand_ssn' do
    context 'ssn is not blank' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '123456789'
        }
      end
      it 'should expand the ssn correctly' do
        new_form_class.send(:expand_ssn)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranSocialSecurityNumber' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber1' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber2' => { 'first' => '123', 'second' => '45', 'third' => '6789' }
        )
      end
    end
  end

  describe '#expand_veteran_full_name' do
    context 'contains middle initial' do
      let :form_data do
        {
          'veteranFullName' => {
            'first' => 'Testy',
            'middle' => 'Tester',
            'last' => 'Testerson'
          }
        }
      end
      it 'should expand veteran full name correctly' do
        new_form_class.send(:expand_veteran_full_name)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranFullName' => {
            'first' => 'Testy',
            'middle' => 'Tester',
            'last' => 'Testerson',
            'middleInitial' => 'T'
          }
        )
      end
    end
  end

  describe '#expand_veteran_dob' do
    context 'dob is not blank' do
      let :form_data do
        {
          'veteranDateOfBirth' => '1981-11-05'
        }
      end
      it 'should expand the birth date correctly' do
        new_form_class.send(:expand_veteran_dob)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranDateOfBirth' => {
            'year' => '1981',
            'month' => '11',
            'day' => '05'
          }
        )
      end
    end
  end

  describe '#expand_veteran_address' do
    context 'contains address' do
      let :form_data do
        {
          'veteranAddress' => {
            'street' => '23195 WRATHALL DR',
            'street2' => '4C',
            'city' => 'ASHBURN',
            'country' => 'USA',
            'state' => 'VA',
            'postalCode' => '20148-1234'
          }
        }
      end
      it 'should expand veteran full name correctly' do
        new_form_class.send(:expand_veteran_address)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranAddress' => {
            'street' => '23195 WRATHALL DR',
            'street2' => '4C',
            'city' => 'ASHBURN',
            'country' => 'US',
            'state' => 'VA',
            'postalCode' => {
              'firstFive' => '20148',
              'lastFour' => '1234'
            }
          }
        )
      end
    end
  end
end
