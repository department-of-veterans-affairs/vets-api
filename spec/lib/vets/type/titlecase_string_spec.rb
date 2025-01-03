# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/titlecase_string'

RSpec.describe Vets::Type::TitlecaseString do
  let(:name) { 'test_titlecase_string' }
  let(:klass) { String }
  let(:titlecase_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(titlecase_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a lowercase string' do
      let(:lowercase_string) { 'hello world' }

      it 'returns the string in titlecase' do
        expect(titlecase_instance.cast(lowercase_string)).to eq('Hello World')
      end
    end

    context 'when value is an already titlecased string' do
      let(:titlecase_string) { 'Hello World' }

      it 'returns the string as is' do
        expect(titlecase_instance.cast(titlecase_string)).to eq('Hello World')
      end
    end

    context 'when value is a string with mixed case' do
      let(:mixed_case_string) { 'hElLo WoRLd' }

      it 'returns the string in titlecase' do
        expect(titlecase_instance.cast(mixed_case_string)).to eq('Hello World')
      end
    end

    context 'when value is a non-string type' do
      let(:non_string_value) { 12_345 }

      it 'returns the string representation of the value in titlecase' do
        expect(titlecase_instance.cast(non_string_value)).to eq('12345')
      end
    end
  end
end
