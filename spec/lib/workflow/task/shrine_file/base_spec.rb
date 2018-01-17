# frozen_string_literal: true

require 'rails_helper'

class SpecShrine < Shrine
  plugin :refresh_metadata
  def extract_filename(_io)
    'not-the-name.txt'
  end
end

# workflow/file_spec.rb covers the instantiation of a lot
# of the internal data that this task uses.
describe Workflow::Task::ShrineFile::Base do
  let(:file) { File.open(Rails.root.join('README.md')) }
  let(:other_file) { File.open(Rails.root.join('CONTRIBUTING.md')) }
  let(:attacher) do
    a = Shrine::Attacher.new(InternalAttachment.new, :file)
    a.assign(file)
    a
  end
  let(:internal) do
    { file: attacher.read }
  end
  let(:internal_with_klass) do
    internal.merge(attacher_class: 'SpecShrine::Attacher')
  end
  context '#initialize' do
    it 'calls the workflow::task initializer' do
      instance = described_class.new({ x: true, y: [1, 2, 3] }, internal: internal)
      expect(instance.data).to eq(x: true, y: [1, 2, 3], current_task: 'Base')
    end

    it 'sets a file handle accessor' do
      instance = described_class.new(internal: internal)
      expect(instance.file.original_filename).to eq('README.md')
      expect(instance.file.download).to be_a_kind_of(Tempfile)
    end

    it 'adds the initial file to history' do
      instance = described_class.new(internal: internal)
      expect(instance.history.first.original_filename).to eq('README.md')
      expect(instance.file.download).to be_a_kind_of(Tempfile)
    end

    it 'uses the attacher_class' do
      instance = described_class.new({ x: true }, internal: internal_with_klass)
      expect(instance.attacher).to be_a(SpecShrine::Attacher)
      instance.file.refresh_metadata!
      expect(instance.file.original_filename).to eq('not-the-name.txt')
    end
  end

  context 'update_file' do
    it 'accepts an IO and sets it as the current file' do
      instance = described_class.new(internal: internal)
      instance.update_file(io: other_file, tag: 'use contributing instead')
      expect(instance.history.length).to be(2)
      expect(instance.history.last.original_filename).to eq('CONTRIBUTING.md')
      expect(instance.file.original_filename).to eq('CONTRIBUTING.md')
    end
  end
end
