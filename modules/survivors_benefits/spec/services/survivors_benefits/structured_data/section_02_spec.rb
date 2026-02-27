# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_02'

RSpec.describe SurvivorsBenefits::StructuredData::Section02 do
  describe '#merge_claimants_id_info' do
    it 'calls merge_name_fields' do
      form = { 'claimantFullName' => { 'first' => 'Jane', 'last' => 'Smith' } }
      individual = 'CLAIMANT'
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_name_fields).with(form['claimantFullName'], individual)
      service.merge_claimants_id_info
    end

    it 'calls merge_claimant_address_fields' do
      form = {
        'claimantAddress' => { 'street' => '123 A St', 'city' => 'Anytown', 'state' => 'VA', 'postalCode' => '12345' }
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_claimant_address_fields).with(form['claimantAddress'])
      service.merge_claimants_id_info
    end

    it 'calls merge_relationship' do
      form = { 'claimantRelationship' => 'SURVIVING_SPOUSE' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_relationship).with(form['claimantRelationship'])
      service.merge_claimants_id_info
    end

    it 'calls merge_claim_type_fields' do
      form = { 'claims' => { 'DIC' => true, 'survivorsPension' => true, 'accruedBenefits' => true } }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_claim_type_fields).with(form['claims'])
      service.merge_claimants_id_info
    end

    it 'merges claimant veteran status and ID info' do
      form = {
        'claimantIsVeteran' => true,
        'claimantSocialSecurityNumber' => '987654321',
        'claimantDateOfBirth' => '1980-02-02',
        'claimantEmail' => 'jane.smith@example.com'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.merge_claimants_id_info
      expect(service.fields).to include(
        'CLAIMANT_VETERAN_Y' => true,
        'CLAIMANT_VETERAN_N' => false,
        'CLAIMANT_SSN' => '987654321',
        'CLAIMANT_DOB' => '02/02/1980',
        'EMAIL' => 'jane.smith@example.com'
      )
    end

    describe 'when claimant phone and address country are present' do
      it 'merges phone number' do
        form = {
          'claimantPhone' => '555-123-4567',
          'claimantAddress' => { 'country' => 'US' }
        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_claimants_id_info
        expect(service.fields).to include(
          'PHONE_NUMBER' => '555-123-4567',
          'INT_PHONE_NUMBER' => nil
        )
      end

      describe 'when claimant phone and non-US address country are present' do
        it 'merges phone number as international phone number' do
          form = {
            'claimantPhone' => '5551234567',
            'claimantAddress' => { 'country' => 'CA' }
          }
          service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
          service.merge_claimants_id_info
          expect(service.fields).to include(
            'PHONE_NUMBER' => '5551234567',
            'INT_PHONE_NUMBER' => '5551234567'
          )
        end
      end

      describe 'when claimant international phone is present' do
        it 'merges international phone number' do
          form = {
            'claimantInternationalPhone' => '+52-5551234567'
          }
          service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
          service.merge_claimants_id_info
          expect(service.fields).to include(
            'PHONE_NUMBER' => nil,
            'INT_PHONE_NUMBER' => '525551234567'
          )
        end
      end
    end
  end

  describe '#merge_claimant_address_fields' do
    it 'merges claimant address fields into the correct structured data' do
      form = {
        'claimantAddress' => {
          'street' => '123 A St',
          'street2' => 'Apt 4',
          'city' => 'Anytown',
          'state' => 'VA',
          'country' => 'USA',
          'postalCode' => '12345'
        }
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.merge_claimant_address_fields(form['claimantAddress'])
      expect(service.fields).to include(
        'CLAIMANT_ADDRESS_FULL_BLOCK' => "123 A St Apt 4 Anytown VA 12345 USA",
        'CLAIMANT_ADDRESS_LINE1' => '123 A St',
        'CLAIMANT_ADDRESS_LINE2' => 'Apt 4',
        'CLAIMANT_ADDRESS_CITY' => 'Anytown',
        'CLAIMANT_ADDRESS_STATE' => 'VA',
        'CLAIMANT_ADDRESS_COUNTRY' => 'USA',
        'CLAIMANT_ADDRESS_ZIP5' => '12345'
      )
    end
  end

  describe '#merge_relationship' do
    let(:relationships) do
      %w[SURVIVING_SPOUSE CHILD_18-23_IN_SCHOOL CUSTODIAN_FILING_FOR_CHILD_UNDER_18 HELPLESS_ADULT_CHILD]
    end

    it 'merges claimant relationship fields into the correct structured data' do
      relationships.each do |relationship|
        form = { 'claimantRelationship' => relationship }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_relationship(form['claimantRelationship'])
        expect(service.fields).to include(
          'RELATIONSHIP_SURVIVING_SPOUSE' => relationship == 'SURVIVING_SPOUSE',
          'RELATIONSHIP_CHILD' => relationship == 'CHILD_18-23_IN_SCHOOL',
          'RELATIONSHIP_CUSTODIAN' => relationship == 'CUSTODIAN_FILING_FOR_CHILD_UNDER_18',
          'RELATIONSHIP_HELPLESSCHILD' => relationship == 'HELPLESS_ADULT_CHILD'
        )
      end
    end
  end

  describe '#merge_claim_type_fields' do
    let(:claims) do
      [
        { 'DIC' => true, 'survivorsPension' => false, 'accruedBenefits' => false },
        { 'DIC' => false, 'survivorsPension' => true, 'accruedBenefits' => false },
        { 'DIC' => false, 'survivorsPension' => false, 'accruedBenefits' => true },
        { 'DIC' => true, 'survivorsPension' => true, 'accruedBenefits' => true },
        { 'DIC' => false, 'survivorsPension' => false, 'accruedBenefits' => false },
        { 'DIC' => true, 'survivorsPension' => true, 'accruedBenefits' => false },
        { 'DIC' => true, 'survivorsPension' => false, 'accruedBenefits' => true },
        { 'DIC' => false, 'survivorsPension' => true, 'accruedBenefits' => true }
      ]
    end

    it 'merges claim type fields into the correct structured data' do
      claims.each do |claim|
        form = { 'claims' => claim }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_claim_type_fields(form['claims'])
        expect(service.fields).to include(
          'CLAIM_TYPE_DIC' => claim['DIC'],
          'CLAIM_TYPE_SURVIVOR_PENSION' => claim['survivorsPension'],
          'CLAIM_TYPE_ACCRUED_BENEFITS' => claim['accruedBenefits']
        )
      end
    end
  end
end
