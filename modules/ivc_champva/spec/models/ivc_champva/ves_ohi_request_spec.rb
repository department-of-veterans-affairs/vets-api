# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VesOhiRequest do
  describe 'constants' do
    it 'returns correct FORM_TYPE' do
      expect(described_class::FORM_TYPE).to eq('vha_10_7959c')
    end

    it 'returns correct APPLICATION_TYPE' do
      expect(described_class::APPLICATION_TYPE).to eq('CHAMPVA_INS_APPLICATION')
    end
  end

  describe '#initialize' do
    it 'generates UUIDs when not provided' do
      request = described_class.new
      expect(request.application_uuid).to match(/\A[0-9a-f-]{36}\z/)
      expect(request.transaction_uuid).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'uses provided UUIDs' do
      request = described_class.new(application_uuid: 'app-123', transaction_uuid: 'trans-456')
      expect(request.application_uuid).to eq('app-123')
      expect(request.transaction_uuid).to eq('trans-456')
    end

    it 'initializes nested objects' do
      request = described_class.new(
        beneficiary_medicare: {
          first_name: 'Jane',
          last_name: 'Doe',
          medicare_parts: [{ medicare_part_type: 'MEDICARE_PART_A', effective_date: '2024-01-01' }],
          other_insurances: [{ insurance_name: 'Aetna' }]
        },
        certification: { signature: 'Jane Doe' }
      )

      expect(request.beneficiary_medicare.first_name).to eq('Jane')
      expect(request.beneficiary_medicare.medicare_parts.first.medicare_part_type).to eq('MEDICARE_PART_A')
      expect(request.beneficiary_medicare.other_insurances.first.insurance_name).to eq('Aetna')
      expect(request.certification.signature).to eq('Jane Doe')
    end
  end

  describe '#form_type' do
    it 'returns FORM_TYPE constant' do
      expect(described_class.new.form_type).to eq('vha_10_7959c')
    end
  end

  describe '#to_json' do
    it 'serializes to valid JSON with camelCase keys matching VES swagger' do
      request = described_class.new(
        application_uuid: 'app-uuid',
        beneficiary_medicare: {
          person_uuid: 'person-uuid',
          first_name: 'Jane',
          last_name: 'Doe',
          ssn: '123456789',
          date_of_birth: '1990-01-15',
          address: { street_address: '123 Main St', city: 'Anytown', state: 'VA', zip_code: '12345' },
          medicare_bene_id: '1EG4TE5MK73',
          medicare_parts: [{ medicare_part_type: 'MEDICARE_PART_A', effective_date: '2024-01-01' }],
          other_insurances: [{ insurance_name: 'Blue Cross', insurance_plan_type: 'hmo' }],
          email_address: 'jane@example.com',
          phone_number: '5551234567',
          gender: 'FEMALE',
          is_new_address: false
        },
        certification: {
          signature: 'Jane Doe',
          signature_date: '2024-12-01'
        }
      )

      json = JSON.parse(request.to_json)

      # Top-level structure matches VES swagger
      expect(json['applicationUUID']).to eq('app-uuid')
      expect(json['applicationType']).to eq('CHAMPVA_INS_APPLICATION')

      # beneficiaryMedicare structure
      bene = json['beneficiaryMedicare']
      expect(bene['personUUID']).to eq('person-uuid')
      expect(bene['firstName']).to eq('Jane')
      expect(bene['lastName']).to eq('Doe')
      expect(bene['ssn']).to eq('123456789')
      expect(bene['dateOfBirth']).to eq('1990-01-15')
      expect(bene['address']['streetAddress']).to eq('123 Main St')
      expect(bene['medicareBeneId']).to eq('1EG4TE5MK73')
      expect(bene['medicareParts'].first['medicarePartType']).to eq('MEDICARE_PART_A')
      expect(bene['otherInsurances'].first['insuranceName']).to eq('Blue Cross')
      expect(bene['otherInsurances'].first['insurancePlanType']).to eq('HMO')
      expect(bene['emailAddress']).to eq('jane@example.com')
      expect(bene['phoneNumber']).to eq('5551234567')
      expect(bene['gender']).to eq('FEMALE')
      expect(bene['isNewAddress']).to be(false)

      # certification structure - only signature and signatureDate are populated from form data
      cert = json['certification']
      expect(cert['signature']).to eq('Jane Doe')
      expect(cert['signatureDate']).to eq('2024-12-01')
    end

    it 'excludes nil values' do
      request = described_class.new(application_uuid: 'app-uuid')
      json = JSON.parse(request.to_json)

      expect(json['beneficiaryMedicare']).not_to have_key('personUUID')
      expect(json['beneficiaryMedicare']).not_to have_key('medicareBeneId')
    end
  end

  describe 'MedicarePart' do
    describe '#initialize' do
      it 'stores medicare_part_type as provided (normalization happens in formatter)' do
        part = described_class::MedicarePart.new(medicare_part_type: 'MEDICARE_PART_A')
        expect(part.medicare_part_type).to eq('MEDICARE_PART_A')

        part = described_class::MedicarePart.new(medicare_part_type: 'MEDICARE_PART_B')
        expect(part.medicare_part_type).to eq('MEDICARE_PART_B')

        part = described_class::MedicarePart.new(medicare_part_type: 'MEDICARE_PART_D')
        expect(part.medicare_part_type).to eq('MEDICARE_PART_D')
      end
    end

    describe '#to_hash' do
      it 'serializes to VES format' do
        part = described_class::MedicarePart.new(
          medicare_part_type: 'MEDICARE_PART_D',
          effective_date: '2024-01-01',
          termination_date: '2025-12-31'
        )
        hash = part.to_hash

        expect(hash[:medicarePartType]).to eq('MEDICARE_PART_D')
        expect(hash[:effectiveDate]).to eq('2024-01-01')
        expect(hash[:terminationDate]).to eq('2025-12-31')
      end
    end
  end

  describe 'OtherInsurance' do
    describe '#initialize' do
      it 'normalizes plan type to VES enum format' do
        ins = described_class::OtherInsurance.new(insurance_plan_type: 'hmo')
        expect(ins.insurance_plan_type).to eq('HMO')

        ins = described_class::OtherInsurance.new(insurance_type: 'medigap_plan')
        expect(ins.insurance_plan_type).to eq('MEDIGAP_PLAN')
      end

      it 'maps legacy field names' do
        ins = described_class::OtherInsurance.new(
          provider: 'Blue Cross',
          expiration_date: '2025-12-31',
          through_employer: true,
          eob: true,
          additional_comments: 'Notes here'
        )

        expect(ins.insurance_name).to eq('Blue Cross')
        expect(ins.termination_date).to eq('2025-12-31')
        expect(ins.is_through_employment).to be(true)
        expect(ins.eob_indicator).to be(true)
        expect(ins.comments).to eq('Notes here')
      end
    end

    describe '#to_hash' do
      it 'serializes to VES swagger field names' do
        ins = described_class::OtherInsurance.new(
          insurance_name: 'Aetna',
          effective_date: '2024-01-01',
          termination_date: '2024-12-31',
          insurance_plan_type: 'ppo',
          is_through_employment: true,
          is_prescription_covered: false,
          eob_indicator: true,
          comments: 'Primary insurance'
        )
        hash = ins.to_hash

        expect(hash[:insuranceName]).to eq('Aetna')
        expect(hash[:effectiveDate]).to eq('2024-01-01')
        expect(hash[:terminationDate]).to eq('2024-12-31')
        expect(hash[:insurancePlanType]).to eq('PPO')
        expect(hash[:isThroughEmployment]).to be(true)
        expect(hash[:isPrescriptionCovered]).to be(false)
        expect(hash[:eobIndicator]).to be(true)
        expect(hash[:comments]).to eq('Primary insurance')
      end
    end
  end

  describe 'Certification' do
    describe '#initialize' do
      it 'maps legacy field names from form data' do
        cert = described_class::Certification.new(
          statement_of_truth_signature: 'John Doe',
          certification_date: '2024-12-01'
        )

        expect(cert.signature).to eq('John Doe')
        expect(cert.signature_date).to eq('2024-12-01')
      end

      it 'derives signed_by_other as false when certifier_role is applicant' do
        cert = described_class::Certification.new(
          signature: 'Jane Doe',
          certifier_role: 'applicant'
        )

        expect(cert.signed_by_other).to be(false)
      end

      it 'derives signed_by_other as true when certifier_role is sponsor' do
        cert = described_class::Certification.new(
          signature: 'Jane Doe',
          certifier_role: 'sponsor'
        )

        expect(cert.signed_by_other).to be(true)
      end

      it 'derives signed_by_other as true when certifier_role is other' do
        cert = described_class::Certification.new(
          signature: 'Jane Doe',
          certifier_role: 'other'
        )

        expect(cert.signed_by_other).to be(true)
      end

      it 'derives signed_by_other as true when certifier_role is nil' do
        cert = described_class::Certification.new(
          signature: 'Jane Doe'
        )

        # nil != 'applicant', so signed_by_other is true
        expect(cert.signed_by_other).to be(true)
      end
    end

    describe '#to_hash' do
      it 'serializes signature, signature_date, and signed_by_other' do
        cert = described_class::Certification.new(
          signature: 'Jane Doe',
          signature_date: '2024-12-01',
          certifier_role: 'other'
        )
        hash = cert.to_hash

        expect(hash[:signature]).to eq('Jane Doe')
        expect(hash[:signatureDate]).to eq('2024-12-01')
        expect(hash[:signedbyOther]).to be(true)
      end
    end
  end

  describe 'Address' do
    describe '#to_hash' do
      it 'includes all VES swagger address fields' do
        addr = described_class::Address.new(
          street_address: '123 Main St',
          city: 'Anytown',
          state: 'VA',
          zip_code: '12345',
          country: 'USA'
        )
        hash = addr.to_hash

        expect(hash[:streetAddress]).to eq('123 Main St')
        expect(hash[:city]).to eq('Anytown')
        expect(hash[:state]).to eq('VA')
        expect(hash[:zipCode]).to eq('12345')
        expect(hash[:country]).to eq('USA')
      end

      it 'handles international addresses with province and postal_code' do
        addr = described_class::Address.new(
          street_address: '10 Downing St',
          city: 'London',
          province: 'Greater London',
          postal_code: 'SW1A 2AA',
          country: 'GBR'
        )
        hash = addr.to_hash

        expect(hash[:streetAddress]).to eq('10 Downing St')
        expect(hash[:city]).to eq('London')
        expect(hash[:province]).to eq('Greater London')
        expect(hash[:postalCode]).to eq('SW1A 2AA')
        expect(hash[:country]).to eq('GBR')
      end
    end
  end
end
