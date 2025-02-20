# frozen_string_literal: true

require 'rails_helper'
require 'vbs/requests/base'

# rubocop:disable RSpec/SubjectStub
describe VBS::Requests::Base do
  class VBS::Requests::TestRequestModel < VBS::Requests::Base
    HTTP_METHOD = :post
    PATH = '/books'

    def self.schema
      {
        'type' => 'object',
        'required' => %w[title author],
        'properties' => {
          'title' => {
            'type' => 'string'
          },
          'author' => {
            'type' => 'string'
          }
        }
      }
    end

    def data
      # Define the return results in the before hook for each test
    end
  end

  let(:described_class) { VBS::Requests::TestRequestModel }
  let(:subject) { described_class.new }

  describe '#http_method' do
    it 'returns the value set for ::HTTP_METHOD' do
      expect(subject).to respond_to(:http_method)
      expect(subject.http_method).to eq(described_class::HTTP_METHOD)
    end
  end

  describe '#path' do
    it 'returns the value set for ::PATH' do
      expect(subject).to respond_to(:path)
      expect(subject.path).to eq(described_class::PATH)
    end
  end

  describe '#validate!' do
    before do
      validation_options = { errors_as_objects: true, version: :draft6 }
      expect(JSON::Validator).to receive(:fully_validate).with(
        subject.class.schema,
        data,
        validation_options
      ).and_call_original
    end

    context 'with invalid data' do
      let(:data) { { author: 99 } }

      before do
        expect(subject).to receive(:data).and_return(data)
      end

      it 'raises an VBS::Requests::InvalidRequestError' do
        expect { subject.validate! }.to raise_error do |error|
          expect(error).to be_instance_of(VBS::Requests::InvalidRequestError)

          expect(error.errors.size).to eq(2)

          expect(error.errors[0][:schema]).to be_present
          expect(error.errors[0][:fragment]).to eq('#/')
          expect(error.errors[0][:message]).to be_instance_of(String)
          expect(error.errors[0][:message]).to include(
            "The property '#/' did not contain a required property of 'title' in schema"
          )
          expect(error.errors[0][:failed_attribute]).to eq('Required')

          expect(error.errors[1][:schema]).to be_present
          expect(error.errors[1][:fragment]).to eq('#/author')
          expect(error.errors[1][:message]).to be_instance_of(String)
          expect(error.errors[1][:message]).to include(
            "The property '#/author' of type integer did not match the following type: string in schema"
          )
          expect(error.errors[1][:failed_attribute]).to eq('TypeV4')

          expect(error.message).to be_instance_of(String)
          expect(error.message).to include("The property '#/' did not contain a required property of 'title' in schema")
          expect(error.message).to include(
            "The property '#/author' of type integer did not match the following type: string in schema"
          )
        end
      end

      it 'sets the @errors attribute to the list of errors' do
        expect { subject.validate! }.to raise_error do |error|
          expect(subject.instance_variable_get('@errors')).to eq(error.errors)
          expect(subject.errors).to eq(error.errors)
        end
      end
    end

    context 'with valid data' do
      let(:data) { { title: 'Amature OOP 101', author: 'kevin' } }

      before do
        expect(subject).to receive(:data).and_return(data)
      end

      it 'returns self' do
        expect(subject.validate!).to eq(subject)
      end
    end
  end

  describe '#valid?' do
    context 'when model is not valid' do
      before do
        allow(subject).to receive(:data).and_return({})
        expect(subject).to receive(:validate!).and_call_original
      end

      it 'returns false' do
        expect(subject.valid?).to be(false)
        expect(subject.errors.size).to eq(2)
      end
    end

    context 'when model is valid' do
      let(:data) { { title: 'Amature OOP 101', author: 'kevin' } }

      before do
        expect(subject).to receive(:data).and_return(data)
        expect(subject).to receive(:validate!).and_return(subject).and_call_original
      end

      it 'returns true' do
        expect(subject.valid?).to be(true)
        expect(subject.errors).to eq([])
      end
    end
  end
end
# rubocop:enable RSpec/SubjectStub
