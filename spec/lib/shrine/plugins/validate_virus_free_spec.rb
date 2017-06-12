# frozen_string_literal: true
require 'rails_helper'
require 'shrine/plugins/validate_virus_free'

describe Shrine::Plugins::ValidateVirusFree do
  describe '#validate_virus_free' do
    let(:klass) do
      Class.new do
        include Shrine::Plugins::ValidateVirusFree::AttacherMethods
        def get
          'stuff'
        end

        def errors
          @errors ||= []
        end
      end
    end

    let(:instance) { klass.new }

    before(:each) do
      allow_any_instance_of(klass).to receive(:get)
        .and_return(instance_double('Shrine::UploadedFile', to_io: instance_double('File', path: 'foo/bar.jpg')))
    end

    context 'with the default error message' do
      it 'adds an error if clam scan returns not safe' do
        allow(ClamScan::Client).to receive(:scan)
          .and_return(instance_double('ClamScan::Response', safe?: false))

        expect(instance).to receive(:error_message).once.with(nil)
        instance.validate_virus_free
      end
    end

    context 'with a custom error message' do
      let(:message) { 'oh noes!' }
      it 'adds an error with a custom error message if clam scan returns not safe' do
        allow(ClamScan::Client).to receive(:scan)
          .and_return(instance_double('ClamScan::Response', safe?: false))

        expect(instance).to receive(:error_message).once.with(message)
        instance.validate_virus_free message: message
      end
    end

    it 'does not add an error if clam scan returns safe' do
      allow(ClamScan::Client).to receive(:scan)
        .and_return(instance_double('ClamScan::Response', safe?: true))

      expect(instance).not_to receive(:add_error)
      instance.validate_virus_free
    end
  end
end
