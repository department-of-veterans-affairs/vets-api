# frozen_string_literal: true
require 'rails_helper'

require 'workflow/task/common/convert_to_pdf'

describe Workflow::Task::Common::ConvertToPdf do
  let(:file) { File.open(Rails.root.join('spec', 'support', 'fixtures', 'va.gif')) }
  let(:attacher) do
    a = Shrine::Attacher.new(InternalAttachment.new, :file)
    a.assign(file)
    a
  end
  let(:instance) { described_class.new(internal: { file: attacher.read }) }

  describe '#run' do
    it 'converts an image to pdf format' do
      expect(instance.file.metadata['mime_type']).to eq('image/gif')
      instance.run
      expect(instance.file.metadata['mime_type']).to eq('application/pdf')
    end
    after { instance.attacher.store.storage.clear! }
  end
end
