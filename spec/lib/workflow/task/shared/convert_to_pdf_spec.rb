# frozen_string_literal: true

require 'rails_helper'

describe Workflow::Task::Shared::ConvertToPdf do
  let(:attacher) do
    a = Shrine::Attacher.new(InternalAttachment.new, :file)
    a.assign(file)
    a
  end
  let(:instance) { described_class.new(internal: { file: attacher.read }) }

  describe '#run' do
    context 'with an image' do
      let(:file) { File.open(Rails.root.join('spec', 'fixtures', 'files', 'va.gif')) }

      it 'converts an image to pdf format' do
        expect(instance.file.metadata['mime_type']).to eq('image/gif')
        instance.run
        expect(instance.file.metadata['mime_type']).to eq('application/pdf')
      end
    end

    context 'when an image is not what it seems' do
      it 'raise an IOError' do
        expect { instance.run }.to raise_error IOError, 'PDF conversion failed, unsupported file type: text/plain'
      end
    end

    after(:each) { instance.attacher.store.storage.clear! }
  end
end
