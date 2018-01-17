# frozen_string_literal: true

require 'rails_helper'

require 'workflow/task/shared/move_to_lts'

describe Workflow::Task::Shared::MoveToLTS do
  let(:file_one) { File.open(Rails.root.join('.ruby-version')) }
  let(:file_two) { File.open(Rails.root.join('Procfile')) }
  let(:attacher) do
    a = Shrine::Attacher.new(InternalAttachment.new, :file)
    a.assign(file_one)
    a
  end
  let(:internal) do
    { file: attacher.read }
  end

  let(:instance) { described_class.new(internal: internal) }

  describe '#run' do
    before do
      instance.attacher.store.storage.clear!
      instance.update_file(io: file_two)
    end
    context 'without :all' do
      it 'moves only the active file' do
        expect { instance.run }.to change { instance.attacher.store.storage.store.keys.count }.from(0).to(1)
        expect(instance.attacher.store.storage.store.first[1]).to eq(File.read(file_two))
        expect(instance.attacher.stored?).to be(true)
        expect(instance.attacher.cached?).to be(false)
      end
    end

    context 'with :all' do
      it 'adds all files to store' do
        expect { instance.run(all: true) }.to change { instance.attacher.store.storage.store.keys.count }.from(0).to(2)
        expect(instance.history.size).to eq(4)
        expect(instance.history.select { |h| h.data['storage'] == 'store' }.count).to eq(2)
        expect(instance.attacher.stored?).to be(true)
        expect(instance.attacher.cached?).to be(false)
        expect(instance.file.original_filename).to eq(File.basename(file_two))
      end
    end
  end
end
