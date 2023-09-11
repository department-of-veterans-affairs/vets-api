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

    before do
      allow_any_instance_of(klass).to receive(:get)
        .and_return(instance_double('Shrine::UploadedFile', download: instance_double('File', path: 'foo/bar.jpg')))

      allow(File).to receive(:chmod).with(0o640, 'foo/bar.jpg').and_return(1)
    end

    context 'with errors' do
      before do
        allow(ClamScan.configuration).to receive(:client_location).and_return('found')
      end

      context 'while in development' do
        it 'logs an error message if clamd is not running' do
          expect(Rails.env).to receive(:development?).and_return(true)
          expect(Rails.logger).to receive(:error).with(/PLEASE START CLAMD/)
          allow(ClamScan::Client).to receive(:scan)
            .and_return(instance_double('ClamScan::Response',
                                        safe?: false,
                                        body: 'ERROR: Could not lookup : nodename nor servname provided, or not known'))

          result = instance.validate_virus_free
          expect(result).to be(true)
        end
      end

      context 'with the default error message' do
        it 'adds an error if clam scan returns not safe' do
          allow(ClamScan::Client).to receive(:scan)
            .and_return(instance_double('ClamScan::Response', safe?: false, body: nil))

          result = instance.validate_virus_free
          expect(result).to be(false)
          expect(instance.errors).to eq(['virus or malware detected'])
        end
      end

      context 'with a custom error message' do
        let(:message) { 'oh noes!' }

        it 'adds an error with a custom error message if clam scan returns not safe' do
          allow(ClamScan::Client).to receive(:scan)
            .and_return(instance_double('ClamScan::Response', safe?: false))

          result = instance.validate_virus_free(message:)
          expect(result).to be(false)
          expect(instance.errors).to eq(['oh noes!'])
        end
      end
    end

    it 'does not add an error if clam scan returns safe' do
      allow(ClamScan::Client).to receive(:scan)
        .and_return(instance_double('ClamScan::Response', safe?: true))

      expect(instance).not_to receive(:add_error_msg)
      result = instance.validate_virus_free
      expect(result).to be(true)
    end

    it 'changes group permissions of the uploaded file' do
      allow(ClamScan::Client).to receive(:scan)
        .and_return(instance_double('ClamScan::Response', safe?: true))

      expect(File).to receive(:chmod).with(0o640, 'foo/bar.jpg').and_return(1)
      instance.validate_virus_free
    end
  end
end
