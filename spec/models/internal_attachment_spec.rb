# frozen_string_literal: true

RSpec.describe InternalAttachment do
  let(:attachment) do
    InternalAttachment.new(a: 1, b: [1, 2, 3])
  end

  context '#initialize' do
    it 'has a file_data attribute' do
      expect(attachment).to respond_to(:file_data)
    end

    it 'creates attributes for arguments' do
      expect(attachment).to respond_to(:a)
      expect(attachment).to respond_to(:b)
      expect(attachment.a).to eq(1)
      expect(attachment.b).to eq([1, 2, 3])
    end
  end

  context 'shrine functionality' do
    it 'functions as a shrine attacher' do
      attacher = SpecUploaderClass::Attacher.new(attachment, :file)
      attacher.assign(File.open(Rails.root.join('README.md')))
      expect(attacher.get.mime_type).to eq('text/plain')
      expect(attacher.errors).to be_empty
    end
  end
end
