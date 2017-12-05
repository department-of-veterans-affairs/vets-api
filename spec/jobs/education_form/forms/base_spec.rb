# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::Base, type: :model, form: :education_benefits do
  let!(:application) { FactoryBot.create(:va1990).education_benefits_claim }
  let(:renderer) { described_class.new(application) }

  context 'build' do
    it 'returns 1990 forms' do
      expect(described_class.build(application)).to be_a(EducationForm::Forms::VA1990)
    end
  end

  describe '#hours_and_type' do
    let(:training) do
      {}
    end

    subject do
      renderer.hours_and_type(OpenStruct.new(training))
    end

    context 'with hours' do
      let(:training) do
        {
          hours: 4
        }
      end

      it 'should output the hours' do
        expect(subject).to eq('4')
      end
    end

    context 'with hours and hours_type' do
      let(:training) do
        {
          hours: 4,
          hoursType: 'semester'
        }
      end

      it 'should output hours and hours_type' do
        expect(subject).to eq('4 (semester)')
      end
    end

    context 'without hours' do
      it 'should return blank string' do
        expect(subject).to eq('')
      end
    end
  end

  context 'yesno' do
    it 'returns N/A for nil values' do
      expect(renderer.yesno(nil)).to eq('N/A')
    end
    it 'returns NO for falsey values' do
      expect(renderer.yesno(false)).to eq('NO')
    end
    it 'returns YES for truthy values' do
      expect(renderer.yesno(true)).to eq('YES')
      expect(renderer.yesno('true')).to eq('YES')
    end
  end

  describe '#benefit_type' do
    let(:education_benefits_claim) { create(:va1990e).education_benefits_claim }

    subject do
      described_class.new(education_benefits_claim)
    end

    it 'should return the benefit type shorthand' do
      expect(subject.benefit_type(education_benefits_claim.open_struct_form)).to eq('CH33')
    end
  end

  context '#full_name' do
    let(:name) { OpenStruct.new(first: 'Mark', last: 'Olson') }
    subject { renderer.full_name(name) }

    context 'with no middle name' do
      it 'should not have extra spaces' do
        expect(subject).to eq('Mark Olson')
      end
    end

    context 'with a middle name' do
      it 'should be included' do
        name.middle = 'Middle'
        expect(subject).to eq 'Mark Middle Olson'
      end
    end
  end

  context '#full_address' do
    let(:address) { application.open_struct_form.veteranAddress }

    subject { renderer.full_address(address) }

    context 'with a nil address' do
      let(:address) { nil }

      it 'should return the blank string' do
        expect(subject).to eq('')
      end
    end

    context 'with no street2' do
      it 'should format the address correctly' do
        expect(subject).to eq("123 MAIN ST\nMILWAUKEE, WI, 53130\nUSA")
      end
    end

    context 'with no state' do
      before do
        address.state = nil
      end

      it 'should format the address correctly' do
        expect(subject).to eq("123 MAIN ST\nMILWAUKEE, 53130\nUSA")
      end

      context 'with no city and zip' do
        before do
          address.city = nil
          address.postalCode = nil
        end

        it 'should format the address correctly' do
          expect(subject).to eq("123 MAIN ST\n\nUSA")
        end
      end
    end

    context 'with a street2' do
      before do
        address.street2 = 'apt 2'
      end

      it 'should format the address correctly' do
        expect(subject).to eq("123 MAIN ST\nAPT 2\nMILWAUKEE, WI, 53130\nUSA")
      end
    end
  end
end
