# frozen_string_literal: true
require 'rails_helper'
require_dependency 'common/client/errors'

# FIXME: Add this spec
describe Common::Client::Errors::ClientResponse do
  subject { described_class.new(status_code, parsed_json) }

  context 'with status code 400 and error 139' do
    let(:status_code) { 400 }
    let(:parsed_json) { JSON.parse(File.read('spec/support/fixtures/post_refill_error.json')) }

    it 'should have error' do
      expect(subject.error).to eq(subject)
    end

    it 'should have major' do
      expect(subject.major).to eq(400)
    end

    it 'should have minor' do
      expect(subject.minor).to eq(139)
    end

    it 'should have message' do
      expect(subject.message).to eq('Prescription is not refillable')
    end

    it 'should have developer message' do
      expect(subject.developer_message).to eq('')
    end

    it 'should respond to to_json' do
      expect(subject.to_json).to be_a(String)
    end

    it 'should respond to to_s' do
      expect(subject.to_s).to eq(subject.to_json)
    end

    context 'Rails environment' do
      let(:expected_json) { File.read('spec/support/fixtures/error_message.txt').strip }

      it 'in development should respond to to_json with developer message and other fields' do
        allow(Rails).to receive_message_chain(:env, :development?).and_return(true)
        expect(subject.to_json)
          .to eq(expected_json)
      end

      it 'in test should respond to to_json with developer message and other fields' do
        allow(Rails).to receive_message_chain(:env, :development?).and_return(false)
        allow(Rails).to receive_message_chain(:env, :test?).and_return(true)
        expect(subject.to_json)
          .to eq(expected_json)
      end
    end
  end
end
