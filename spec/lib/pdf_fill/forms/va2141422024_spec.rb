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
    context 'form data with a domestic phone number' do
      it 'transforms form data into PDF-compatible format', run_at: '2016-12-31 00:00:00 EDT' do
        expect(JSON.parse(described_class.new(get_fixture('pdf_fill/21-4142-2024/kitchen_sink'))
        .merge_fields.to_json)).to eq(
          JSON.parse(get_fixture('pdf_fill/21-4142-2024/merge_fields').to_json)
        )
      end
    end

    context 'form data with an international phone number' do
      it 'transforms form data into PDF-compatible format', run_at: '2016-12-31 00:00:00 EDT' do
        expect(JSON.parse(described_class.new(get_fixture('pdf_fill/21-4142-2024/kitchen_sink_intl_phone'))
        .merge_fields.to_json)).to eq(
          JSON.parse(get_fixture('pdf_fill/21-4142-2024/merge_fields_intl_phone').to_json)
        )
      end
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
    context 'when email is less than 15 characters' do
      let(:form_data) do
        {
          'email' => 'test1@gmail.com'
        }
      end

      it 'does not split the email' do
        new_form_class.expand_email_address
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'email' => 'test1@gmail.com'
        )
      end
    end

    context 'when email is exactly 16 characters' do
      let(:form_data) do
        {
          'email' => 'test12@gmail.com'
        }
      end

      it 'splits the email correctly' do
        new_form_class.expand_email_address
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'email' => 'test12@gmail.co',
          'email1' => 'm'
        )
      end
    end

    context 'when email is between 16 and 30 characters' do
      let(:form_data) do
        {
          'email' => 'verylongemail@example.com'
        }
      end

      it 'splits the email at character 15' do
        new_form_class.expand_email_address
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'email' => 'verylongemail@e',
          'email1' => 'xample.com'
        )
      end
    end

    context 'when email is exactly 30 characters' do
      let(:form_data) do
        {
          'email' => 'superlongusername@exampl.com'
        }
      end

      it 'splits the email correctly' do
        new_form_class.expand_email_address
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'email' => 'superlonguserna',
          'email1' => 'me@exampl.com'
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
        new_form_class.expand_phone_number_field
        expect(
          JSON.parse(class_form_data.to_json)
        ).to eq(
          'veteranPhone' => { 'phone_area_code' => '619', 'phone_first_three_numbers' => '555',
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
              'from' => '1980-01-01',
              'to' => '1985-01-01'
            }
          ]
        },
        {
          'providerFacilityName' => 'provider 2',
          'treatmentDateRange' => [
            {
              'from' => '1980-02-01',
              'to' => '1985-02-01'
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
                'from' => '1980-01-01',
                'to' => '1985-01-01'
              }
            ],
            'dateRangeStart' => {
              'month' => '01',
              'day' => '01',
              'year' => '1980'
            },
            'dateRangeEnd' => {
              'month' => '01',
              'day' => '01',
              'year' => '1985'
            }
          },
          {
            'providerFacilityName' => 'provider 2',
            'treatmentDateRange' => [
              {
                'from' => '1980-02-01',
                'to' => '1985-02-01'
              }
            ],
            'dateRangeStart' => {
              'month' => '02',
              'day' => '01',
              'year' => '1980'
            },
            'dateRangeEnd' => {
              'month' => '02',
              'day' => '01',
              'year' => '1985'
            }
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

  describe '#expand_providers' do
    context 'with 5 normal non-overflowing providers' do
      let(:form_data) { get_fixture('pdf_fill/21-4142-2024/kitchen_sink') }

      it 'expands all 5 providers to provider1-provider5 keys and removes providerFacility' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result).not_to have_key('providerFacility')
        expect(form_data_result).to have_key('provider1')
        expect(form_data_result).to have_key('provider2')
        expect(form_data_result).to have_key('provider3')
        expect(form_data_result).to have_key('provider4')
        expect(form_data_result).to have_key('provider5')

        # Verify provider1 structure and data transformations
        provider1 = form_data_result['provider1']
        expect(provider1['providerFacilityName']).to eq('Provider 1')
        expect(provider1['conditionsTreated']).to eq('Hypertension')

        # Verify address expansion
        expect(provider1['address']).to be_an(Array)
        expect(provider1['address'][0]['street']).to eq('123 Main St')
        expect(provider1['address'][0]['city']).to eq('Baltimore')
        expect(provider1['address'][0]['country']).to eq('US') # Should be converted from 'USA'
        expect(provider1['address'][0]['postalCode']).to have_key('firstFive')
        expect(provider1['address'][0]['postalCode']).to have_key('lastFour')

        # Verify date range expansion
        expect(provider1['dateRangeStart']).to have_key('month')
        expect(provider1['dateRangeStart']).to have_key('day')
        expect(provider1['dateRangeStart']).to have_key('year')
        expect(provider1['dateRangeStart']['year']).to eq('2010')

        expect(provider1['dateRangeEnd']).to have_key('month')
        expect(provider1['dateRangeEnd']).to have_key('day')
        expect(provider1['dateRangeEnd']).to have_key('year')
        expect(provider1['dateRangeEnd']['year']).to eq('2011')

        # Verify no overflow for normal providers
        expect(form_data_result['provider1']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider2']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider3']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider4']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider5']).not_to have_key('completeProviderInfo')
      end
    end

    context 'with mixed overflow and normal providers (1-5)' do
      let(:form_data) { get_fixture('pdf_fill/21-4142-2024/providers_mixed_overflow') }

      it 'generates overflow info for providers exceeding field limits' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        # Provider 1: Long facility name (>100 chars) should overflow
        expect(form_data_result['provider1']['completeProviderInfo']).to be_present
        overflow_obj1 = form_data_result['provider1']['completeProviderInfo'][0]
        overflow_text1 = overflow_obj1['extras_value']
        expected_overflow_string1 = <<~TEXT.chomp
          Provider or Facility Name: OVERFLOW TEST: Provider Name That Exceeds The Allowed 100 Characters To Test Name Overflow In PDF Fields

          Address: 123 Main St
          Apt A
          Baltimore, MD, 21201
          USA

          Conditions Treated: Hypertension

          Treatment Date Ranges: from: 01-01-2010 to: 01-01-2011
        TEXT

        expect(overflow_text1).to include('Provider or Facility Name:')
        expect(overflow_text1).to include(expected_overflow_string1)
        expect(overflow_text1).to include('Address:')
        expect(overflow_text1).to include('Conditions Treated: Hypertension')
        expect(overflow_text1).to include('Treatment Date Ranges:')
        expect(overflow_text1).to include('from: 01-01-2010 to: 01-01-2011')

        # Provider 2: Long address should overflow
        expect(form_data_result['provider2']['completeProviderInfo']).to be_present
        overflow_obj2 = form_data_result['provider2']['completeProviderInfo'][0]
        overflow_text2 = overflow_obj2['extras_value']
        expected_overflow_string2 = <<~TEXT.chomp
          Provider or Facility Name: Normal Provider Name

          Address: OVERFLOW TEST: 456 Street Address for Testing
          Apt 101
          Chicago, IL, 60601
          USA

          Conditions Treated: Diabetes Type 2

          Treatment Date Ranges: from: 01-01-2011 to: 01-01-2012
        TEXT

        expect(overflow_text2).to include('Conditions Treated:')
        expect(overflow_text2).to include(expected_overflow_string2)

        # Provider 3: Long street address (>30 chars) should overflow
        expect(form_data_result['provider3']['completeProviderInfo']).to be_present
        expect(form_data_result['provider3']['addressOverflows']).to be true

        # Provider 4: Long street2 (>5 chars) should overflow
        expect(form_data_result['provider4']['completeProviderInfo']).to be_present
        expect(form_data_result['provider4']['addressOverflows']).to be true

        # Provider 5: Long city (>18 chars) should overflow
        expect(form_data_result['provider5']['completeProviderInfo']).to be_present
        expect(form_data_result['provider5']['addressOverflows']).to be true
      end
    end

    context 'with providers exceeding 5 (additionalProvider6-50)' do
      let(:form_data) { get_fixture('pdf_fill/21-4142-2024/overflow') }

      it 'maps first 5 providers to provider1-5 and remaining to additionalProvider6+' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        # First 5 providers should be mapped to provider1-5, the fifth provider will have name "See add'l info page"
        # because our test data has more than 5 providers
        (1..4).each do |i|
          expect(form_data_result).to have_key("provider#{i}")
          expect(form_data_result["provider#{i}"]['providerFacilityName']).to include("Provider #{i}")
        end

        # Additional providers should be mapped to additionalProvider6+
        expect(form_data_result).to have_key('additionalProvider6')
        expect(form_data_result).to have_key('additionalProvider7')
        expect(form_data_result).to have_key('additionalProvider8')

        # Provider 5 should be forced to overflow with continuation message in name input field
        expect(form_data_result['provider5']['providerFacilityName']).to eq("See add'l info page")
        expect(form_data_result['provider5']['completeProviderInfo']).to be_present

        # Verify additional providers contain complete provider info
        expect(form_data_result['additionalProvider6']).to be_present
        expect(form_data_result['additionalProvider7']).to be_present
        expect(form_data_result['additionalProvider8']).to be_present

        # Original providerFacility should be removed
        expect(form_data_result).not_to have_key('providerFacility')
      end
    end

    context 'when forcing provider 5 overflow for 6+ providers' do
      let(:form_data) { get_fixture('pdf_fill/21-4142-2024/overflow') }

      it 'forces provider5 to overflow and shows continuation message when there are 6+ providers' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        # Provider 5 should have its name changed to indicate additional info page
        expect(form_data_result['provider5']['providerFacilityName']).to eq("See add'l info page")

        # Provider 5 should have completeProviderInfo generated with original data
        expect(form_data_result['provider5']['completeProviderInfo']).to be_present
        overflow_obj = form_data_result['provider5']['completeProviderInfo'][0]
        overflow_text = overflow_obj['extras_value']
        expect(overflow_text).to include('Provider or Facility Name: Provider 5')
        expect(overflow_text).to include('Conditions Treated: PTSD')
        expect(overflow_text).to include('Address:')
        expect(overflow_text).to include('Treatment Date Ranges:')

        # Sixth provider should be in additionalProvider6
        expect(form_data_result['additionalProvider6']).to be_present

        # Providers 1-4 should remain normal (no forced overflow)
        (1..4).each do |i|
          expect(form_data_result["provider#{i}"]['providerFacilityName']).to eq("Provider #{i}")
          expect(form_data_result["provider#{i}"]).not_to have_key('completeProviderInfo')
        end
      end
    end

    context 'when providerFacility array is empty or nil' do
      context 'with empty array' do
        let(:form_data) { { 'providerFacility' => [] } }

        it 'returns early and leaves empty providerFacility key unchanged' do
          new_form_class.expand_providers
          form_data_result = JSON.parse(class_form_data.to_json)

          # The method returns early for empty arrays, so the key remains
          expect(form_data_result).to have_key('providerFacility')
          expect(form_data_result['providerFacility']).to eq([])

          # No provider keys should be created
          expect(form_data_result).not_to have_key('provider1')
          expect(form_data_result).not_to have_key('provider2')
          expect(form_data_result).not_to have_key('additionalProvider6')
        end
      end

      context 'with nil value' do
        let(:form_data) { { 'providerFacility' => nil } }

        it 'returns early without modifying form_data' do
          original_data = form_data.dup
          new_form_class.expand_providers
          form_data_result = JSON.parse(class_form_data.to_json)

          expect(form_data_result).to eq(JSON.parse(original_data.to_json))
        end
      end
    end
  end

  describe 'PROVIDER_NAME_AND_CONDITIONS_TREATED_MAX constant' do
    it 'has the correct value of 60' do
      expect(described_class::PROVIDER_NAME_AND_CONDITIONS_TREATED_MAX).to eq(60)
    end
  end

  describe '#provider_info_overflows?' do
    context 'with provider name exactly at the 60 character limit' do
      let(:provider_data) do
        {
          'providerFacilityName' => 'a' * 60,
          'conditionsTreated' => 'Condition',
          'addressOverflows' => false
        }
      end

      it 'does not consider this as overflowing' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be false
      end
    end

    context 'with provider name exceeding the 60 character limit' do
      let(:provider_data) do
        {
          'providerFacilityName' => 'a' * 61,
          'conditionsTreated' => 'Condition',
          'addressOverflows' => false
        }
      end

      it 'considers this as overflowing' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be true
      end
    end

    context 'with conditions treated exactly at the 60 character limit' do
      let(:provider_data) do
        {
          'providerFacilityName' => 'Provider Name',
          'conditionsTreated' => 'a' * 60,
          'addressOverflows' => false
        }
      end

      it 'does not consider this as overflowing' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be false
      end
    end

    context 'with conditions treated exceeding the 60 character limit' do
      let(:provider_data) do
        {
          'providerFacilityName' => 'Provider Name',
          'conditionsTreated' => 'a' * 61,
          'addressOverflows' => false
        }
      end

      it 'considers this as overflowing' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be true
      end
    end

    context 'with addressOverflows set to true' do
      let(:provider_data) do
        {
          'providerFacilityName' => 'Short Name',
          'conditionsTreated' => 'Short Condition',
          'addressOverflows' => true
        }
      end

      it 'considers this as overflowing regardless of name/condition length' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be true
      end
    end

    context 'with nil provider name and conditions' do
      let(:provider_data) do
        {
          'providerFacilityName' => nil,
          'conditionsTreated' => nil,
          'addressOverflows' => false
        }
      end

      it 'does not consider this as overflowing' do
        result = new_form_class.send(:provider_info_overflows?, provider_data)
        expect(result).to be false
      end
    end
  end

  describe 'overflow behavior with 60 character limit' do
    context 'when provider name is exactly 60 characters' do
      let(:form_data) do
        {
          'providerFacility' => [
            {
              'providerFacilityName' => 'a' * 60,
              'conditionsTreated' => 'Hypertension',
              'treatmentDateRange' => [{ 'from' => '2020-01-01', 'to' => '2021-01-01' }],
              'providerFacilityAddress' => {
                'street' => '123 Main St',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'USA',
                'postalCode' => '21201'
              }
            }
          ]
        }
      end

      it 'does not generate overflow content' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result['provider1']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider1']['providerFacilityName']).to eq('a' * 60)
      end
    end

    context 'when provider name is 61 characters (exceeds limit)' do
      let(:form_data) do
        {
          'providerFacility' => [
            {
              'providerFacilityName' => 'a' * 61,
              'conditionsTreated' => 'Hypertension',
              'treatmentDateRange' => [{ 'from' => '2020-01-01', 'to' => '2021-01-01' }],
              'providerFacilityAddress' => {
                'street' => '123 Main St',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'USA',
                'postalCode' => '21201'
              }
            }
          ]
        }
      end

      it 'generates overflow content' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result['provider1']).to have_key('completeProviderInfo')
        overflow_text = form_data_result['provider1']['completeProviderInfo'][0]['extras_value']
        expect(overflow_text).to include("Provider or Facility Name: #{'a' * 61}")
        expect(overflow_text).to include('Conditions Treated: Hypertension')
      end
    end

    context 'when conditions treated is exactly 60 characters' do
      let(:form_data) do
        {
          'providerFacility' => [
            {
              'providerFacilityName' => 'Provider Name',
              'conditionsTreated' => 'b' * 60,
              'treatmentDateRange' => [{ 'from' => '2020-01-01', 'to' => '2021-01-01' }],
              'providerFacilityAddress' => {
                'street' => '123 Main St',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'USA',
                'postalCode' => '21201'
              }
            }
          ]
        }
      end

      it 'does not generate overflow content' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result['provider1']).not_to have_key('completeProviderInfo')
        expect(form_data_result['provider1']['conditionsTreated']).to eq('b' * 60)
      end
    end

    context 'when conditions treated is 61 characters (exceeds limit)' do
      let(:form_data) do
        {
          'providerFacility' => [
            {
              'providerFacilityName' => 'Provider Name',
              'conditionsTreated' => 'b' * 61,
              'treatmentDateRange' => [{ 'from' => '2020-01-01', 'to' => '2021-01-01' }],
              'providerFacilityAddress' => {
                'street' => '123 Main St',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'USA',
                'postalCode' => '21201'
              }
            }
          ]
        }
      end

      it 'generates overflow content' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result['provider1']).to have_key('completeProviderInfo')
        overflow_text = form_data_result['provider1']['completeProviderInfo'][0]['extras_value']
        expect(overflow_text).to include('Provider or Facility Name: Provider Name')
        expect(overflow_text).to include("Conditions Treated: #{'b' * 61}")
      end
    end

    context 'when both provider name and conditions treated exceed 60 characters' do
      let(:form_data) do
        {
          'providerFacility' => [
            {
              'providerFacilityName' => 'c' * 61,
              'conditionsTreated' => 'd' * 61,
              'treatmentDateRange' => [{ 'from' => '2020-01-01', 'to' => '2021-01-01' }],
              'providerFacilityAddress' => {
                'street' => '123 Main St',
                'city' => 'Baltimore',
                'state' => 'MD',
                'country' => 'USA',
                'postalCode' => '21201'
              }
            }
          ]
        }
      end

      it 'generates overflow content with both fields' do
        new_form_class.expand_providers
        form_data_result = JSON.parse(class_form_data.to_json)

        expect(form_data_result['provider1']).to have_key('completeProviderInfo')
        overflow_text = form_data_result['provider1']['completeProviderInfo'][0]['extras_value']
        expect(overflow_text).to include("Provider or Facility Name: #{'c' * 61}")
        expect(overflow_text).to include("Conditions Treated: #{'d' * 61}")
      end
    end
  end

  describe 'PROVIDER_KEYS constant field limits' do
    it 'uses the correct limit for providerFacilityName fields' do
      provider_keys = described_class::PROVIDER_KEYS

      # Check provider1 through provider5
      (1..5).each do |i|
        provider_field = provider_keys["provider#{i}"]
        expect(provider_field['providerFacilityName'][:limit]).to eq(60)
      end
    end

    it 'uses the correct limit for conditionsTreated fields' do
      provider_keys = described_class::PROVIDER_KEYS

      # Check provider1 through provider5
      (1..5).each do |i|
        provider_field = provider_keys["provider#{i}"]
        expect(provider_field['conditionsTreated'][:limit]).to eq(60)
      end
    end
  end

  describe 'ADDITIONAL_PROVIDER_KEYS constant field limits' do
    it 'has the correct structure for overflow providers' do
      additional_provider_keys = described_class::ADDITIONAL_PROVIDER_KEYS

      # Check a few key additional providers to verify they have the correct structure
      [6, 7, 8, 15, 25, 50].each do |i|
        provider_field = additional_provider_keys["additionalProvider#{i}"]
        expect(provider_field).to have_key('completeProviderInfo')
        expect(provider_field['completeProviderInfo']).to have_key(:always_overflow)
        expect(provider_field['completeProviderInfo'][:always_overflow]).to be true
      end
    end

    it 'creates keys for providers 6 through 50' do
      additional_provider_keys = described_class::ADDITIONAL_PROVIDER_KEYS

      # Check that all expected provider keys exist
      (6..50).each do |i|
        expect(additional_provider_keys).to have_key("additionalProvider#{i}")
      end
    end
  end

  describe '#combine_date_ranges_for_overflow' do
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
      expect(new_form_class.combine_date_ranges_for_overflow(date_ranges)).to eq(
        "from: 01-01-1980 to: 01-01-1985\nfrom: 01-01-1986 to: 01-01-1987"
      )
    end

    it 'shows a single date range correctly' do
      date_ranges = [
        {
          'from' => '1980-1-1',
          'to' => '1985-1-1'
        }
      ]
      expect(new_form_class.combine_date_ranges_for_overflow(date_ranges)).to eq(
        'from: 01-01-1980 to: 01-01-1985'
      )
    end

    it 'handles no date ranges' do
      date_ranges = []
      expect(new_form_class.combine_date_ranges_for_overflow(date_ranges)).to eq('')
    end

    it 'handles nil date ranges' do
      date_ranges = nil
      expect(new_form_class.combine_date_ranges_for_overflow(date_ranges)).to eq('')
    end
  end
end
