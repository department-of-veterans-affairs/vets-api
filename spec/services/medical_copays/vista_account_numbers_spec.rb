# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VistaAccountNumbers do
  subject { described_class.build(data:, user:) }

  let(:data) do
    {
      '516' => %w[12345 67891234],
      '553' => %w[2 87234689],
      '201' => %w[12345 3624534],
      '205' => %w[4123456 6123],
      '200' => %w[1234 2345678],
      '983' => %w[3234 335678],
      '987' => %w[4234 435678],
      '984' => %w[5234 535678],
      '988' => %w[6234 635678]
    }
  end

  let(:user) { build(:user, :loa3) }

  before do
    allow(user).to receive(:va_treatment_facility_ids).and_return(data.keys)
  end

  describe 'attributes' do
    it 'responds to data' do
      expect(subject.respond_to?(:data)).to be(true)
    end

    it 'responds to user' do
      expect(subject.respond_to?(:user)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of VistaAccountNumbers' do
      expect(subject).to be_an_instance_of(MedicalCopays::VistaAccountNumbers)
    end
  end

  describe '#list' do
    context 'when no data' do
      it 'returns a default list' do
        allow_any_instance_of(MedicalCopays::VistaAccountNumbers).to receive(:data).and_return({})

        expect(subject.list).to eq([1_234_567_891_011_121])
      end
    end

    context 'when data' do
      it 'returns an array of Vista Account Numbers' do
        vista_num_list = [
          5_160_000_000_012_345,
          5_160_000_067_891_234,
          5_530_000_000_000_002,
          5_530_000_087_234_689,
          2_010_000_000_012_345,
          2_010_000_003_624_534,
          2_050_000_004_123_456,
          2_050_000_000_006_123,
          2_000_000_000_001_234,
          2_000_000_002_345_678,
          9_830_000_000_003_234,
          9_830_000_000_335_678,
          9_870_000_000_004_234,
          9_870_000_000_435_678,
          9_840_000_000_005_234,
          9_840_000_000_535_678,
          9_880_000_000_006_234,
          9_880_000_000_635_678
        ]

        expect(subject.list).to eq(vista_num_list)
      end
    end
  end

  describe '#vista_account_id' do
    context 'when facility_id plus vista_id is not 16 characters in length' do
      it 'builds the vista_account_id' do
        expect(subject.vista_account_id('4234', '2345678')).to eq(4_234_000_002_345_678)
      end

      it 'is 16 characters in length' do
        expect(subject.vista_account_id('4234', '2345678').to_s.length).to eq(16)
      end

      it 'adds the appropriate 0s in between' do
        expect(subject.vista_account_id('4234', '2345678').to_s.scan(/0/).length).to eq(5)
      end
    end

    context 'when facility_id plus vista_id is 16 characters' do
      it 'builds the vista_account_id' do
        expect(subject.vista_account_id('423456', '5212345678')).to eq(4_234_565_212_345_678)
      end

      it 'is 16 characters in length' do
        expect(subject.vista_account_id('423456', '5212345678').to_s.length).to eq(16)
      end

      it 'has no 0s' do
        expect(subject.vista_account_id('423456', '5212345678').to_s.scan(/0/).length).to eq(0)
      end
    end
  end

  describe '#default' do
    it 'returns a default value' do
      expect(subject.default).to eq([1_234_567_891_011_121])
    end
  end

  describe '#treatment_facility_data' do
    it 'returns full hash if all treatment facilities' do
      expect(subject.treatment_facility_data(data)).to eq(data)
    end

    context 'non treatment facilities' do
      before do
        allow_any_instance_of(User).to receive(:va_treatment_facility_ids).and_return(%w[516 553])
      end

      let(:data) do
        {
          '516' => %w[12345 67891234],
          '553' => %w[2 87234689],
          '200HI' => %w[123456789101112131415]
        }
      end

      it 'excludes non treatment facilities' do
        expect(subject.treatment_facility_data(data)).to eq(
          {
            '516' => %w[12345 67891234],
            '553' => %w[2 87234689]
          }
        )
      end
    end
  end
end
