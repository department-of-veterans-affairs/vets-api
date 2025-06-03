# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2141422024'

def basic_class
  PdfFill::Forms::Va2141422024.new({})
end

describe PdfFill::Forms::Va2141422024 do
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
      expect(JSON.parse(described_class.new(get_fixture('pdf_fill/21-4142-2024/kitchen_sink'))
      .merge_fields.to_json)).to eq(
        JSON.parse(get_fixture('pdf_fill/21-4142-2024/merge_fields').to_json)
      )
    end
  end

  describe '#expand_va_file_number' do
    context 'va file number is not blank' do
      let(:form_data) do
        {
          'vaFileNumber' => '796126859'
        }
      end

      it 'expands the va file number correctly' do
        new_form_class.expand_va_file_number
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'vaFileNumber' => '796126859',
          'vaFileNumber1' => '796126859'
        )
      end
    end

    context 'va file number is blank' do
      let(:form_data) do
        {}
      end

      it 'returns without doing anything' do
        new_form_class.expand_va_file_number
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq({})
      end
    end
  end

  describe '#expand_email_address' do
    context 'email address is not blank' do
      let(:form_data) do
        {
          'email' => 'myemail72585885@gmail.com'
        }
      end

      it 'expands the email address correctly' do
        new_form_class.expand_va_file_number
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'email' => 'myemail72585885@gmail.com'
        )
      end
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
        new_form_class.expand_ssn
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranSocialSecurityNumber' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber1' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber2' => { 'first' => '123', 'second' => '45', 'third' => '6789' },
          'veteranSocialSecurityNumber3' => { 'first' => '123', 'second' => '45', 'third' => '6789' }
        )
      end
    end
  end

  describe '#expand_phone_number' do
    context 'phone number is not blank' do
      let(:form_data) do
        {
          'veteranPhone' => '6195551234'
        }
      end

      it 'expands the phone number correctly' do
        new_form_class.expand_phone_number
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranPhone' => { 'phone_area_code' => '619', 'phone_first_three_numbers' => '555',
                              'phone_last_four_numbers' => '1234' },
          'veteranPhone1' => { 'phone_area_code' => '619', 'phone_first_three_numbers' => '555',
                               'phone_last_four_numbers' => '1234' },
          'veteranPhone2' => { 'phone_area_code' => '619', 'phone_first_three_numbers' => '555',
                               'phone_last_four_numbers' => '1234' },
          'veteranPhone3' => { 'phone_area_code' => '619', 'phone_first_three_numbers' => '555',
                               'phone_last_four_numbers' => '1234' }
        )
      end
    end
  end

  describe '#expand_veteran_full_name' do
    context 'contains middle initial' do
      let :form_data do
        {
          'veteranFullName' => {
            'first' => 'Hector',
            'middle' => 'Nick',
            'last' => 'Allen'
          }
        }
      end

      it 'expands veteran full name correctly' do
        new_form_class.expand_veteran_full_name
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranFullName' => {
            'first' => 'Hector',
            'middle' => 'Nick',
            'last' => 'Allen',
            'middleInitial' => 'N'
          },
          'veteranFullName1' => {
            'first' => 'Hector',
            'middle' => 'Nick',
            'last' => 'Allen',
            'middleInitial' => 'N'
          }
        )
      end
    end
  end

  describe '#expand_signature' do
    let(:form_data) do
      { 'signatureDate' => '2017-02-14',
        'veteranFullName' => { 'first' => 'Foo',
                               'last' => 'Bar' } }
    end

    it 'expands the Signature and Signature Date correctly' do
      new_form_class.expand_signature(form_data['veteranFullName'], form_data['signatureDate'])
      # Note on the expectation: the signature field gets filled in further down in the #merge_fields method

      expect(
        JSON.parse(class_form_data.to_json)
      ).to eq(
        'signature' => 'Foo Bar',
        'veteranFullName' => {
          'first' => 'Foo',
          'last' => 'Bar'
        },
        'signatureDate' => '2017-02-14'
      )
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
        new_form_class.expand_veteran_dob
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranDateOfBirth' => {
            'year' => '1981',
            'month' => '11',
            'day' => '05'
          },
          'veteranDateOfBirth1' => {
            'year' => '1981',
            'month' => '11',
            'day' => '05'
          }
        )
      end
    end
  end

  describe '#expand_veteran_service_number' do
    context 'veteran service number is not blank' do
      let :form_data do
        {
          'veteranServiceNumber' => '987654321'
        }
      end

      it 'expands veteran service number correctly' do
        new_form_class.expand_veteran_service_number
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranServiceNumber' => '987654321',
          'veteranServiceNumber1' => '987654321'
        )
      end
    end
  end

  describe '#expand_claimant_address' do
    context 'veteran address is not blank' do
      let(:form_data) do
        {
          'veteranAddress' => {
            'city' => 'Baltimore',
            'country' => 'USA',
            'postalCode' => '21231-1234',
            'street' => 'street',
            'street2' => '1B',
            'state' => 'MD'
          }
        }
      end

      it 'expands postal code and country correctly' do
        new_form_class.expand_claimant_address
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranAddress' => {
            'city' => 'Baltimore',
            'country' => 'US',
            'postalCode' => {
              'firstFive' => '21231',
              'lastFour' => '1234'
            },
            'street' => 'street',
            'street2' => '1B',
            'state' => 'MD'
          }
        )
      end
    end
  end

  describe '#expand_provider_date_range' do
    it 'expands the provider date range correctly' do
      providers = [
        {
          'providerFacilityName' => 'provider 1',
          'treatmentDateRange' => [
            {
              'from' => '1980-1-1',
              'to' => '1985-1-1'
            },
            {
              'from' => '1986-1-1',
              'to' => '1987-1-1'
            }
          ]
        },
        {
          'providerFacilityName' => 'provider 2',
          'treatmentDateRange' => [
            {
              'from' => '1980-2-1',
              'to' => '1985-2-1'
            },
            {
              'from' => '1986-2-1',
              'to' => '1987-2-1'
            }
          ]
        }
      ]
      expect(
        new_form_class.expand_provider_date_range(providers)
      ).to eq(
        [
          {
            'providerFacilityName' => 'provider 1',
            'treatmentDateRange' => [
              {
                'from' => '1980-1-1',
                'to' => '1985-1-1'
              },
              {
                'from' => '1986-1-1',
                'to' => '1987-1-1'
              }
            ],
            'dateRangeStart' => nil,
            'dateRangeEnd' => nil
          },
          {
            'providerFacilityName' => 'provider 2',
            'treatmentDateRange' => [
              {
                'from' => '1980-2-1',
                'to' => '1985-2-1'
              },
              {
                'from' => '1986-2-1',
                'to' => '1987-2-1'
              }
            ],
            'dateRangeStart' => nil,
            'dateRangeEnd' => nil
          }
        ]
      )
    end
  end

  describe '#expand_provider_address' do
    it 'expands the provider address correctly' do
      providers = [
        {
          'providerFacilityName' => 'provider 1',
          'providerFacilityAddress' => {
            'street' => '123 Main Street',
            'street2' => '1B',
            'city' => 'Baltimore',
            'state' => 'MD',
            'country' => 'USA',
            'postalCode' => '21200-1111'
          }
        }
      ]
      expect(
        new_form_class.expand_provider_address(providers)
      ).to eq(
        [
          {
            'providerFacilityName' => 'provider 1',
            'providerFacilityAddress' => {
              'street' => '123 Main Street',
              'street2' => '1B',
              'city' => 'Baltimore',
              'state' => 'MD',
              'country' => 'USA',
              'postalCode' => '21200-1111'
            },
            'address' => [
              {
                'street' => '123 Main Street',
                'street2' => '1B',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'US',
                'postalCode' => {
                  'firstFive' => '21200',
                  'lastFour' => '1111'
                }
              }
            ]
          }
        ]
      )
    end
  end

  describe '#combine_date_ranges' do
    it 'combines multiple date ranges correctly' do
      date_ranges = [
        {
          'from' => '1980-1-1',
          'to' => '1985-1-1'
        },
        {
          'from' => '1986-1-1',
          'to' => '1987-1-1'
        }
      ]
      expect(new_form_class.combine_date_ranges(date_ranges)).to eq(
        "from: 1980-1-1 to: 1985-1-1\nfrom: 1986-1-1 to: 1987-1-1"
      )
    end

    it 'shows a single date range correctly' do
      date_ranges = [
        {
          'from' => '1980-1-1',
          'to' => '1985-1-1'
        }
      ]
      expect(new_form_class.combine_date_ranges(date_ranges)).to eq(
        'from: 1980-1-1 to: 1985-1-1'
      )
    end

    it 'handles no date ranges' do
      date_ranges = []
      expect(new_form_class.combine_date_ranges(date_ranges)).to eq('')
    end
  end
end
