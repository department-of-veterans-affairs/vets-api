# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va218940'

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

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(JSON.parse(described_class.new(get_fixture('pdf_fill/21-8940/kitchen_sink')).merge_fields.to_json)).to eq(
        get_fixture('pdf_fill/21-8940/merge_fields')
      )
    end
  end

  describe '#expand_ssn' do
    context 'ssn is not blank' do
      let(:form_data) do
        {
          'veteranSocialSecurityNumber' => '123456789'
        }
      end

      it 'expands the ssn correctly' do
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

      it 'expands veteran full name correctly' do
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

      it 'expands the birth date correctly' do
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

  describe '#expand_service_connected_disability' do
    context 'disabilityPreventingEmployment is not blank' do
      unemployability = {
        'disabilityPreventingEmployment' => 'Disability Text'
      }
      it 'expands the serviceConnectedDisability correctly' do
        new_form_class.send(:expand_service_connected_disability, unemployability)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'serviceConnectedDisability' => 'Disability Text'
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

      it 'expands veteran address correctly' do
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

  describe '#expand_veteran_doctors_care_or_hospitalized_status' do
    context 'was hospitalized or under doctors care' do
      unemployability = {
        'underDoctorHopitalCarePast12M' => true
      }

      it 'expands veteran address correctly' do
        new_form_class.send(:expand_doctors_care_or_hospitalized, unemployability)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'wasHospitalizedYes' => true,
          'wasHospitalizedNo' => false
        )
      end
    end

    context 'was not hospitalized or under doctors care' do
      unemployability = {
        'underDoctorHopitalCarePast12M' => false
      }
      it 'expands veteran address correctly' do
        new_form_class.send(:expand_doctors_care_or_hospitalized, unemployability)
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'wasHospitalizedYes' => false,
          'wasHospitalizedNo' => true
        )
      end
    end
  end

  describe '#expand_provided_care_date_range' do
    context 'date range is not empty' do
      provided_care = [
        {
          'dates' => 'From 1994-01-01 to 1995-01-01'
        }
      ]
      it 'expands the doctorsCare date range correctly' do
        new_form_class.send(:expand_provided_care_date_range, provided_care, 'doctorsCare')
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'doctorsCareDateRanges' => [
            'From 1994-01-01 to 1995-01-01'
          ]
        )
      end
    end
  end

  describe '#expand_provided_care_details' do
    context 'care name and address is not empty' do
      provided_care = [
        {
          'name' => 'Doctor Smith',
          'address' => {
            'street' => '123 Test St.',
            'state' => 'SC'
          }
        },
        {
          'name' => 'Doctor Jones',
          'address' => {
            'street' => '123 Test St.',
            'street2' => '4B',
            'city' => 'Testville',
            'state' => 'SC',
            'postalCode' => '12345',
            'country' => 'US'
          }
        }
      ]
      it 'expands the doctorsCare name and address correctly' do
        new_form_class.send(:expand_provided_care_details, provided_care, 'doctorsCare')
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'doctorsCareDetails' => [
            { 'value' => "Doctor Smith\n123 Test St.\nSC" },
            { 'value' => "Doctor Jones\n123 Test St. 4B\nTestville SC 12345\nUS" }
          ]
        )
      end
    end
  end

  describe '#expand_provided_care' do
    context 'care name and address is not empty' do
      provided_care = [
        {
          'name' => 'Doctor Smith',
          'address' => {
            'street' => '123 Test St.',
            'state' => 'SC'
          },
          'dates' => 'From 1994-01-01 to 1995-01-01'
        },
        {
          'name' => 'Doctor Jones',
          'address' => {
            'street' => '123 Test St.',
            'street2' => '4B',
            'city' => 'Testville',
            'state' => 'SC',
            'postalCode' => '12345',
            'country' => 'US'
          }
        }
      ]
      it 'expands the doctorsCare name and address correctly' do
        new_form_class.send(:expand_provided_care, provided_care, 'doctorsCare')
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'doctorsCareDetails' => [
            { 'value' => "Doctor Smith\n123 Test St.\nSC" },
            { 'value' => "Doctor Jones\n123 Test St. 4B\nTestville SC 12345\nUS" }
          ],
          'doctorsCareDateRanges' => [
            'From 1994-01-01 to 1995-01-01'
          ]
        )
      end
    end
  end
end
