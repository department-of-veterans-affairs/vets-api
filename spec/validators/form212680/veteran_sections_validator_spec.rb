# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form212680::VeteranSectionsValidator do
  let(:valid_sections) do
    {
      'veteranInformation' => {
        'fullName' => { 'first' => 'John', 'last' => 'Doe' },
        'ssn' => '123456789',
        'vaFileNumber' => '987654321',
        'dateOfBirth' => '1950-01-01'
      },
      'claimantInformation' => {
        'fullName' => { 'first' => 'Jane', 'last' => 'Doe' },
        'relationship' => 'Spouse',
        'address' => {
          'street' => '123 Main St',
          'city' => 'Springfield',
          'state' => 'IL',
          'postalCode' => '62701'
        }
      },
      'benefitInformation' => {
        'claimType' => 'Aid and Attendance'
      },
      'additionalInformation' => {
        'currentlyHospitalized' => false,
        'nursingHome' => false
      },
      'veteranSignature' => {
        'signature' => 'John A Doe',
        'date' => Time.zone.today.to_s
      }
    }
  end

  describe '#valid?' do
    context 'with valid sections' do
      subject { described_class.new(valid_sections) }

      it 'returns true' do
        expect(subject.valid?).to be true
      end

      it 'has no errors' do
        subject.valid?
        expect(subject.errors).to be_empty
      end
    end

    context 'with missing veteran information' do
      subject { described_class.new(sections) }

      let(:sections) { valid_sections.except('veteranInformation') }

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Veteran information is required')
      end
    end

    context 'with missing veteran first name' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranInformation']['fullName']['first'] = nil
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Veteran first name is required')
      end
    end

    context 'with missing veteran last name' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranInformation']['fullName']['last'] = ''
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Veteran last name is required')
      end
    end

    context 'with invalid SSN format' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranInformation']['ssn'] = '12345'
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Invalid Social Security Number format')
      end
    end

    context 'with SSN containing dashes' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranInformation']['ssn'] = '123-45-6789'
        data
      end

      it 'returns true (dashes are stripped)' do
        expect(subject.valid?).to be true
      end
    end

    context 'with missing claimant information' do
      subject { described_class.new(sections) }

      let(:sections) { valid_sections.except('claimantInformation') }

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Claimant information is required')
      end
    end

    context 'with missing claimant address' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['claimantInformation'].delete('address')
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Claimant address is required')
      end
    end

    context 'with missing benefit information' do
      subject { described_class.new(sections) }

      let(:sections) { valid_sections.except('benefitInformation') }

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Benefit information is required')
      end
    end

    context 'with housebound claim type (lowercase)' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['benefitInformation']['claimType'] = 'housebound'
        data
      end

      it 'returns true' do
        expect(subject.valid?).to be true
      end
    end

    context 'with missing veteran signature' do
      subject { described_class.new(sections) }

      let(:sections) { valid_sections.except('veteranSignature') }

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Veteran signature is required')
      end
    end

    context 'with signature date older than 60 days' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranSignature']['date'] = 61.days.ago.to_date.to_s
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Signature date must be within the last 60 days')
      end
    end

    context 'with signature date in the future' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranSignature']['date'] = 1.day.from_now.to_date.to_s
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Signature date cannot be in the future')
      end
    end

    context 'with invalid date format' do
      subject { described_class.new(sections) }

      let(:sections) do
        data = valid_sections.deep_dup
        data['veteranInformation']['dateOfBirth'] = 'invalid-date'
        data
      end

      it 'returns false' do
        expect(subject.valid?).to be false
      end

      it 'includes appropriate error message' do
        subject.valid?
        expect(subject.errors).to include('Invalid date of birth format')
      end
    end
  end

  describe '#errors' do
    context 'with multiple validation errors' do
      subject { described_class.new(sections) }

      let(:sections) do
        {
          'veteranInformation' => {
            'fullName' => { 'first' => nil, 'last' => nil },
            'ssn' => '12345',
            'vaFileNumber' => nil,
            'dateOfBirth' => nil
          }
        }
      end

      it 'collects all validation errors' do
        subject.valid?

        expect(subject.errors.length).to be > 1
        expect(subject.errors).to include('Veteran first name is required')
        expect(subject.errors).to include('Veteran last name is required')
        expect(subject.errors).to include('Invalid Social Security Number format')
      end
    end
  end
end
