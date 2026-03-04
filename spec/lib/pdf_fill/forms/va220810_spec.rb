# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210272'

describe PdfFill::Forms::Va220810 do
  let(:form_data) { get_fixture('pdf_fill/22-0810/kitchen_sink') }
  let(:form) { described_class.new(form_data) }

  describe '#merge_fields' do
    subject(:merged_fields) { form.merge_fields }

    it 'formats name fields into full name with middle initial' do
      first, middle, last = form_data['applicantName'].values
      full_name = merged_fields['applicantName']
      middle_initial = full_name.split[1]
      expect(middle_initial).to eq("#{middle[0]}.")
      expect(full_name).to eq(form.combine_full_name(
                                'first' => first,
                                'middle' => middle_initial,
                                'last' => last
                              ))
    end

    it 'formats mailing address' do
      mailing_address = form_data['mailingAddress']
      form.normalize_mailing_address(mailing_address)
      expect(merged_fields['mailingAddress']).to eq(form.combine_full_address_extras(mailing_address))
    end

    it 'formats phone if domestic' do
      home, mobile = merged_fields['phone'].values
      expect(home).to eq(form.format_us_phone(form_data['homePhone']))
      expect(mobile).to eq(form.format_us_phone(form_data['mobilePhone']))
    end

    it 'does not format phone if international' do
      form_data['mailingAddress']['country'] = 'MEX'
      home, mobile = merged_fields['phone'].values
      expect(home).to eq(form_data['homePhone'])
      expect(mobile).to eq(form_data['mobilePhone'])
    end

    it 'formats ssn' do
      formatted_snn = form_data['ssn'].gsub(/(\d{3})(\d{2})(\d{4})/, '\1-\2-\3')
      expect(merged_fields['ssn']).to eq(formatted_snn)
    end

    it 'formats va file number' do
      expect(merged_fields['vaFileNumber']).to eq("#{form_data['vaFileNumber']}-#{form_data['payeeNumber']}")
    end

    it 'converts hasPreviouslyApplied boolean to Yes/Off' do
      expect(form_data['hasPreviouslyApplied']).to be true
      has_applied_yes, has_applied_no = merged_fields['hasPreviouslyApplied'].values
      expect(has_applied_yes).to eq('Yes')
      expect(has_applied_no).to eq('Off')
    end

    it 'formats organization address' do
      keys = %w[organizationName organizationAddress]
      org = form_data.slice(*keys)
      form.normalize_mailing_address(org['organizationAddress'])
      combined = form.combine_name_addr_extras(org, *keys)
      expect(merged_fields['organization']).to eq(combined)
    end

    it 'formats dates to MM/DD/YYYY' do
      %w[examDate dateSigned].each do |field|
        expect(merged_fields[field]).to match(%r{^(0[1-9]|1[0-2])/(0[1-9]|[12][0-9]|3[01])/\d{4}$})
      end
    end
  end
end
