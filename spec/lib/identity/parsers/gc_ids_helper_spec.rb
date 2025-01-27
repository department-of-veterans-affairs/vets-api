# frozen_string_literal: true

require 'rails_helper'
require 'identity/parsers/gc_ids_helper'

describe Identity::Parsers::GCIdsHelper do
  let(:class_instance) { Class.new { extend Identity::Parsers::GCIdsHelper } }

  describe '#sanitize_edipi' do
    subject { class_instance.sanitize_edipi(edipi) }

    context 'when edipi parameter is nil' do
      let(:edipi) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when edipi parameter is not a string' do
      let(:edipi) { 1234 }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when edipi parameter is a string of a 10 digit number' do
      let(:edipi) { '1234567890' }

      it 'returns the input string without any changes' do
        expect(subject).to eq(edipi)
      end
    end

    context 'when edipi parameter is a string of a less than 10 digit number' do
      let(:edipi) { '1234' }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when edipi parameter is a string of a more than 10 digit number' do
      let(:edipi) { '123412341234' }
      let(:edipi_first_10_digits) { edipi[0..9] }

      it 'returns the first 10 digits of the input string' do
        expect(subject).to eq(edipi_first_10_digits)
      end
    end

    context 'when edipi parameter is a string with a 10 digit number and other characters' do
      let(:edipi) { "kitty#{edipi_digits}puppy" }
      let(:edipi_digits) { '1234123412' }

      it 'returns the first 10 digits of the input string' do
        expect(subject).to eq(edipi_digits)
      end
    end
  end

  describe '#sanitize_id' do
    subject { class_instance.sanitize_id(id) }

    context 'when id parameter is nil' do
      let(:id) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when id parameter is not a string' do
      let(:id) { 1234 }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when id parameter is a string with only digit characters' do
      let(:id) { '1234567890' }

      it 'returns the input string without any changes' do
        expect(subject).to eq(id)
      end
    end

    context 'when id parameter is a string with non-digit characters and digits' do
      let(:id) { "kitty#{id_digits}puppy" }
      let(:id_digits) { '1234' }

      it 'returns the digits only' do
        expect(subject).to eq(id_digits)
      end
    end

    context 'when id parameter is a string with no digit characters' do
      let(:id) { 'some-id' }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when id parameter is a string with a multiple sets of digits separated by non-digit characters' do
      let(:id) { "kitty#{id_digits}puppy#{id_digits_suffix}" }
      let(:id_digits) { '1234123412' }
      let(:id_digits_suffix) { '999' }

      it 'returns only the first set of digits' do
        expect(subject).to eq(id_digits)
      end
    end
  end

  describe '#sanitize_id_array' do
    subject { class_instance.sanitize_id_array(ids) }

    context 'when id parameter is nil' do
      let(:ids) { nil }

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end

    context 'when id parameter is not an array' do
      let(:ids) { 1234 }

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end

    context 'when id parameter is an array of strings with only digit characters' do
      let(:ids) { ['1234567890'] }

      it 'returns the input array without any changes' do
        expect(subject).to eq(ids)
      end
    end

    context 'when id parameter is an array of strings with non-digit characters and digits' do
      let(:ids) { ["kitty#{id_digits}puppy"] }
      let(:id_digits) { '1234' }

      it 'returns an array of strings with the digits only' do
        expect(subject).to eq([id_digits])
      end
    end

    context 'when id parameter is an array of strings with no digit characters' do
      let(:ids) { ['some-id'] }

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end

    context 'when id is an array of strings with a multiple sets of digits separated by non-digit characters' do
      let(:ids) { ["kitty#{id_digits}puppy#{id_digits_suffix}"] }
      let(:id_digits) { '1234123412' }
      let(:id_digits_suffix) { '999' }

      it 'returns an array of strings with only the first set of digits' do
        expect(subject).to eq([id_digits])
      end
    end
  end
end
