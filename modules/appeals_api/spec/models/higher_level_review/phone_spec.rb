# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReview::Phone do
  let(:phone) { described_class.new hash.as_json }

  let(:international_country_code) { '9' }
  let(:us_country_code) { '1' }
  let(:area_code) { '800' }
  let(:phone_number) { '5551234' }
  let(:long_phone_number) { '12345678901234' }
  let(:phone_number_ext) { '987' }

  # 123-123-1234 ext 987
  # +9-123-123-1234 x987

  describe 'to_s' do
    subject { phone.to_s }

    context 'non-international' do
      context 'with country code' do
        let(:hash) do
          {
            countryCode: us_country_code,
            areaCode: area_code,
            phoneNumber: phone_number
          }
        end

        it 'is properly formatted (leaves out country code)' do
          expect(subject).to eq "#{area_code}-#{phone_number[0..2]}-#{phone_number[3..]}"
        end

        it('is not too long') { expect(phone.too_long?).to be false }
      end

      context 'no country code' do
        let(:hash) do
          {
            areaCode: area_code,
            phoneNumber: phone_number
          }
        end

        it 'is properly formatted (leaves out country code)' do
          expect(subject).to eq "#{area_code}-#{phone_number[0..2]}-#{phone_number[3..]}"
        end

        it('is not too long') { expect(phone.too_long?).to be false }
      end
    end

    context 'non-international, with extension' do
      let(:hash) do
        {
          countryCode: us_country_code,
          areaCode: area_code,
          phoneNumber: phone_number,
          phoneNumberExt: phone_number_ext
        }
      end

      it 'is properly formatted (normal extension prefix)' do
        expect(subject).to eq "#{area_code}-#{phone_number[0..2]}-#{phone_number[3..]} ext #{phone_number_ext}"
      end

      it('is not too long') { expect(phone.too_long?).to be false }
    end

    context 'international' do
      let(:hash) do
        {
          countryCode: international_country_code,
          areaCode: area_code,
          phoneNumber: phone_number
        }
      end

      it 'is properly formatted' do
        expect(subject).to eq(
          "+#{international_country_code}-#{area_code}" \
          "-#{phone_number[0..2]}-#{phone_number[3..]}"
        )
      end

      it('is not too long') { expect(phone.too_long?).to be false }
    end

    context 'international, with extension' do
      let(:hash) do
        {
          countryCode: international_country_code,
          areaCode: area_code,
          phoneNumber: phone_number,
          phoneNumberExt: phone_number_ext
        }
      end

      it 'is properly formatted (uses short extension prefix)' do
        expect(subject).to eq(
          "+#{international_country_code}-#{area_code}" \
          "-#{phone_number[0..2]}-#{phone_number[3..]} x#{phone_number_ext}"
        )
      end

      it('is not too long') { expect(phone.too_long?).to be false }

      context 'longer phone_number_ext' do
        let(:phone_number_ext) { '9876' }

        it 'is properly formatted (uses short extension prefix)' do
          expect(subject).to eq(
            "+#{international_country_code}-#{area_code}" \
            "-#{phone_number[0..2]}-#{phone_number[3..]}x#{phone_number_ext}"
          )
        end

        it('is not too long') { expect(phone.too_long?).to be false }
      end

      context 'even longer phone_number_ext (phone number too long)' do
        let(:phone_number_ext) { '98765' }

        it 'is properly formatted (uses short extension prefix)' do
          expect(subject).to eq(
            "+#{international_country_code}-#{area_code}" \
            "-#{phone_number[0..2]}-#{phone_number[3..]}x#{phone_number_ext}"
          )
        end

        it('is not too long') { expect(phone.too_long?).to be true }
      end
    end
  end
end
