# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/validate_unlocked_pdf'

describe Shrine::Plugins::ValidateAscii do
  include SpecTempFiles
  describe '#validate_ascii' do
    let(:ascii) { 'yes hello' }
    let(:nonascii) { "I \u2661 Unicode!" }

    let(:klass) do
      Class.new do
        include Shrine::Plugins::ValidateAscii::AttacherMethods
        def get
          raise "shouldn't be called"
        end

        def errors
          @errors ||= []
        end
      end
    end

    let(:instance) { klass.new }

    let(:attachment) do
      instance_double('Shrine::UploadedFile', original_filename: File.basename(file), to_io: File.open(file, 'r+'))
    end

    before do
      allow(instance).to receive(:get).and_return(attachment)
      allow(attachment).to receive(:replace)
    end

    context 'with non-txt file' do
      let(:file) { temp(['test', '.doc'], ascii) }

      it 'does not run any checks' do
        expect(attachment).not_to receive(:to_io)
        expect { instance.validate_ascii }.not_to change { instance.errors.count }
      end
    end

    context 'with normal ascii file' do
      let(:file) { temp(['test', '.doc'], ascii) }

      it 'does not add any errors' do
        expect { instance.validate_ascii }.not_to change { instance.errors.count }
      end
    end

    context 'with utf16 ascii file' do
      let(:file) { temp(['test', '.txt'], ascii, encoding: 'utf-16be') }

      it 'does not add any errors' do
        expect { instance.validate_ascii }.not_to change { instance.errors.count }
      end
    end

    context 'with a file containing unicode' do
      let(:file) { temp(['test', '.txt'], nonascii) }

      it 'adds an error' do
        expect { instance.validate_ascii }.to change { instance.errors.count }.from(0).to(1)
        expect(instance.errors.first).to eq I18n.t('uploads.text.not_ascii')
      end
    end
  end
end
