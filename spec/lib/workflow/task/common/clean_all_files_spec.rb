# frozen_string_literal: true
require 'rails_helper'

require 'workflow/task/common/move_to_lts'

describe Workflow::Task::Common::CleanAllFiles do
  describe '#run' do
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

    before do
      instance.update_file(io: file_two)
    end

    context 'with :all' do
      it 'removes all files to store' do
        instance.run
        expect(instance.attacher.cache.storage.store.keys).to be_empty
        expect(instance.attacher.store.storage.store.keys).to be_empty
      end
    end
  end
end
