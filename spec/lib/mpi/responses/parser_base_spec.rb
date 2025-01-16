# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/parser_base'

describe MPI::Responses::ParserBase do
  describe '#unknown_error?' do
    subject { described_class.new(code).unknown_error? }

    context 'when code is set to nil' do
      let(:code) { nil }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#failed_or_invalid?' do
    subject { described_class.new(code).failed_or_invalid? }

    context 'when code is set to failure response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:failure] }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when code is set to invalid response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:invalid_request] }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#failed_request?' do
    subject { described_class.new(code).failed_request? }

    context 'when code is set to failure response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:failure] }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#invalid_request?' do
    subject { described_class.new(code).invalid_request? }

    context 'when code is set to invalie response code' do
      let(:code) { MPI::Responses::ParserBase::EXTERNAL_RESPONSE_CODES[:invalid_request] }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when code is set to an arbitrary value' do
      let(:code) { 'some-code' }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#locate_element' do
    subject { described_class.new.locate_element(el, path_to_parse) }

    let(:path_to_parse) { 'some_path_to_parse' }

    context 'when el parameter is nil' do
      let(:el) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when el parameter is not an Ox XML parsing object' do
      let(:el) { 'some-parameter' }

      it 'returns nil' do
        expect(subject).to be_nil
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
          expect(subject).to be_nil
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

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when el parameter is not an Ox XML parsing object' do
      let(:el) { 'some-parameter' }

      it 'returns empty array' do
        expect(subject).to eq([])
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
