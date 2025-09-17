# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210275'

describe PdfFill::Forms::Va2210275 do
  let(:form_data) { get_fixture('pdf_fill/22-10275/kitchen_sink') }
  let(:form_class) { described_class.new(form_data) }

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields }

    it 'flattens nested address attributes into string mailing address' do
      address = form_data['mainInstitution']['institutionAddress']
      address.delete('country')
      mailing_address = form_class.combine_full_address_extras(address)
      expect(merged_fields.dig('mainInstitution', 'mailingAddress')).to eq(mailing_address)
    end

    it 'includes country in mailing address if address international' do
      form_data['mainInstitution']['institutionAddress']['country'] = 'MEX'
      expect(merged_fields.dig('mainInstitution', 'mailingAddress')).to include('MX')
    end

    it 'formats state if country Mexico' do
      form_data['mainInstitution']['institutionAddress']['country'] = 'MEX'
      form_data['mainInstitution']['institutionAddress']['state'] = 'baja-california-sur'
      expect(merged_fields.dig('mainInstitution', 'mailingAddress')).to include('Baja California Sur')
    end

    it 'converts agreement type booleans to Yes/Off' do
      agreement = merged_fields['agreementType']
      expect(agreement['newCommitment']).to eq('Yes')
      expect(agreement['withdrawal']).to eq('Off')
    end

    it 'formats address of each additional institution' do
      address = form_data['additionalInstitutions'].first['institutionAddress']
      address.delete('country')
      mailing_address = form_class.combine_full_address(address)
      expect(merged_fields['additionalInstitutions'].first['institutionAddress'])
        .to eq(mailing_address)
    end

    it 'formats contact name of each additional institution' do
      contact = form_data['additionalInstitutions'].first['pointOfContact']
      name = form_class.combine_full_name(contact['fullName'])
      expect(merged_fields['additionalInstitutions'].first['fullName']).to eq(name)
    end

    it 'formats contact name and phone for POC and SCO' do
      %w[principlesOfExcellencePointOfContact schoolCertifyingOfficial].each do |official|
        contact = form_data.dig('newCommitment', official)
        name = form_class.combine_full_name(contact['fullName'])
        expect(merged_fields.dig('newCommitment', official, 'fullName')).to eq(name)

        phone = form_class.expand_phone_number(contact['usPhone']).values.join('-')
        expect(merged_fields.dig('newCommitment', official, 'phone')).to eq(phone)
      end
    end

    it 'doesn\'t format phone if international' do
      form_data['newCommitment']['schoolCertifyingOfficial'].delete('usPhone')
      phone = '12345678910'
      form_data['newCommitment']['schoolCertifyingOfficial']['internationalPhone'] = phone
      expect(merged_fields.dig('newCommitment', 'schoolCertifyingOfficial', 'phone')).to eq(phone)
    end

    it 'formats contact name and phone for authorizing official' do
      contact = form_data['authorizedOfficial']
      name = form_class.combine_full_name(contact['fullName'])
      expect(merged_fields.dig('authorizedOfficial', 'fullName')).to eq(name)

      phone = form_class.expand_phone_number(contact['usPhone']).values.join('-')
      expect(merged_fields.dig('authorizedOfficial', 'phone')).to eq(phone)
    end
  end
end
