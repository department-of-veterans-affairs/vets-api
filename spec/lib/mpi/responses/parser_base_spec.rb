# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/parser_base'

describe MPI::Responses::ParserBase do
  describe '#failed_or_invalid?' do
    subject { described_class.new(code).failed_or_invalid? }

    context 'when code is set to failure response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:failure] }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when code is set to invalid response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:invalid_request] }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#failed_request?' do
    subject { described_class.new(code).failed_request? }

    context 'when code is set to failure response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:failure] }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#invalid_request?' do
    subject { described_class.new(code).invalid_request? }

    context 'when code is set to invalie response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:invalid_request] }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#sanitize_edipi' do
    subject { described_class.new.sanitize_edipi(edipi) }

    context 'when edipi parameter is nil' do
      let(:edipi) { nil }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when edipi parameter is not a string' do
      let(:edipi) { 1234 }

      it 'returns nil' do
        expect(subject).to be(nil)
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
        expect(subject).to be(nil)
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
    subject { described_class.new.sanitize_id(id) }

    context 'when id parameter is nil' do
      let(:id) { nil }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when id parameter is not a string' do
      let(:id) { 1234 }

      it 'returns nil' do
        expect(subject).to be(nil)
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
        expect(subject).to be(nil)
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

  describe '#locate_element' do
    subject { described_class.new.locate_element(el, path_to_parse) }

    let(:path_to_parse) { 'some_path_to_parse' }

    context 'when el parameter is nil' do
      let(:el) { nil }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when el parameter is not an Ox XML parsing object' do
      let(:el) { 'some-parameter' }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when el parameter is an Ox XML parsing object' do
      let(:el) { Ox::Document.new << ox_element }
      let(:ox_element) { Ox::Element.new(parse_field) }
      let(:parse_field) { 'element-to-parse' }
      let(:path_to_parse) { parse_field }

      context 'and the path parameter does not correspond to an attribute in the Ox object' do
        let(:path_to_parse) { 'incorrect-parse' }

        it 'returns nil' do
          expect(subject).to eq(nil)
        end
      end

      context 'and the path parameter corresponds to an attribute in the Ox object' do
        let(:path_to_parse) { parse_field }

        it 'returns the first matching parsed element' do
          expect(subject).to eq(ox_element)
        end
      end
    end
  end

  describe '#locate_elements' do
    subject { described_class.new.locate_elements(el, path_to_parse) }

    let(:path_to_parse) { 'some_path_to_parse' }

    context 'when el parameter is nil' do
      let(:el) { nil }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when el parameter is not an Ox XML parsing object' do
      let(:el) { 'some-parameter' }

      it 'returns nil' do
        expect(subject).to be(nil)
      end
    end

    context 'when el parameter is an Ox XML parsing object' do
      let(:el) { Ox::Document.new << ox_element }
      let(:ox_element) { Ox::Element.new(parse_field) }
      let(:parse_field) { 'element-to-parse' }
      let(:path_to_parse) { parse_field }

      context 'and the path parameter does not correspond to an attribute in the Ox object' do
        let(:path_to_parse) { 'incorrect-parse' }

        it 'returns empty array' do
          expect(subject).to eq([])
        end
      end

      context 'and the path parameter corresponds to an attribute in the Ox object' do
        let(:path_to_parse) { parse_field }

        it 'returns an array with the matching parsed element' do
          expect(subject).to eq([ox_element])
        end
      end
    end
  end
end
