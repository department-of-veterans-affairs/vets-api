# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::V0::RawFormData, type: :model do
  subject { described_class.new(attributes) }

  describe 'with valid attributes' do
    let(:attributes) { { email: 'jane.doe@email.com', zip_code: '12345-1234', vaccine_interest: 'yes' } }

    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end
  end

  describe '', :aggregate_failures do
    context 'without presence of email' do
      let(:attributes) { { zip_code: '12345-1234', vaccine_interest: 'yes' } }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(['Email is invalid'])
      end
    end

    context 'with an invalid email address' do
      let(:attributes) { { email: 'jane.doe@', zip_code: '12345-1234', vaccine_interest: 'yes' } }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(['Email is invalid'])
      end
    end

    context 'without presence of zip_code' do
      let(:attributes) { { email: 'jane.doe@email.com', vaccine_interest: 'yes' } }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(['Zip code should be in the form 12345 or 12345-1234'])
      end
    end

    context 'with an invalid zip_code' do
      let(:attributes) { { email: 'jane.doe@email.com', zip_code: '1234', vaccine_interest: 'yes' } }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(['Zip code should be in the form 12345 or 12345-1234'])
      end
    end

    context 'without presence of vaccine_interest' do
      let(:attributes) { { email: 'jane.doe@email.com', zip_code: '12345-1234' } }

      it 'is not valid without the presence of vaccine_interest' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(["Vaccine interest can't be blank"])
      end
    end

    context 'without presence of birth_date' do
      let(:attributes) do
        { email: 'jane.doe@email.com', zip_code: '12345-1234',
          vaccine_interest: 'yes', birth_date: '' }
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with a structurally invalid birth_date' do
      let(:attributes) do
        { email: 'jane.doe@email.com', zip_code: '12345-1234',
          vaccine_interest: 'yes', birth_date: '1999-01-XX' }
      end

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages)
          .to eq(['Birth date should be in the form yyyy-mm-dd'])
      end
    end
  end
end
