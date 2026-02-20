# spec/services/mss/form4140_ibm_converter_spec.rb
require 'rails_helper'


require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::Mms::VBA214140IbmConverter do
  let(:form) do
    OpenStruct.new(
      first_name: 'John',
      middle_initial: 'Q',
      last_name: 'Doe',
      ssn: ['123','45','6789'],
      dob: '1980-01-15',
      phone_primary: '(555) 123-4567',
      signature_employed: 'John Doe',
      signature_date_employed: '2024-01-01',
      data: { 'email_address' => 'TEST@EMAIL.COM', 'id_number' => { 'va_file_number' => 'VA123' },  'date_of_birth' => '1980-01-15' },
      address: OpenStruct.new(
        address_line1: '123 Main',
        address_line2: 'Apt 2',
        address_line3: 'Attn: Testing',
        city: 'Austin',
        state_code: 'TX',
        country_code_iso2: 'US',
        zip_code: '78701-1234'
      ),
      employment_history: [
        OpenStruct.new(
          type_of_work: 'Full-time',
          hours_per_week: '40',
          lost_time_from_illness: '13',
          highest_gross_income_per_month: 2300,
          employment_dates: { from: '2018-03-15', to: '2020-06-30' },
          name_and_address: 'IBM Corp',
		  employer_address: OpenStruct.new(
		            country: 'USA',
		            street: '1234 Executive Ave',
		            city: 'Metropolis',
		            state: 'CA',
		            postal_code: '90210'
          )
        )
      ]
    )
  end


  describe '.convert' do
    subject(:payload) { described_class.convert(form) }

    it 'normalizes SSN' do
      expect(payload['VETERAN_SSN']).to eq('123456789')
    end

    it 'formats DOB as MMDDYYYY' do
      expect(payload['VETERAN_DOB']).to eq('01151980')
    end

    it 'downcases email' do
      expect(payload['EMAIL']).to eq('test@email.com')
    end

    it 'includes employer info' do
      expect(payload['EMPLOYER_NAME_ADDRESS']).to eq('IBM Corp')
    end

    it 'includes full name correctly' do
      expect(payload['VETERAN_NAME']).to eq('John Q Doe')
    end

    it 'truncates first name correctly' do
      expect(payload['VETERAN_FIRST_NAME']).to eq('John')
    end
  end
end