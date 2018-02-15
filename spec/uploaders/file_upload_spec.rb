# frozen_string_literal: true

require 'rails_helper'

class SpecUploaderClass < Shrine
  plugin :validation_helpers
  Attacher.validate do
    # validate_min_size 1024
    validate_min_size 1.kilobytes
  end
end

class SpecUploaderTask < Workflow::Task::ShrineFile::Base
  def run(options)
    logger.fatal("ran anonymous task with options #{options} and data #{data}")
  end
end

class SpecUploaderWorkflow < Workflow::File
  run SpecUploaderTask, run: 'this'
end

RSpec.describe FileUpload do
  let(:klass) { Class.new(FileUpload) }

  context '#initialize' do
    it 'raises an error when no uploaded is provided' do
      expect { klass.new }.to raise_exception(/uploader/)
    end

    it 'raises and error when no workflow is provided' do
      klass.uploader = Class.new(Shrine)
      expect { klass.new }.to raise_exception(/workflow/)
    end
  end

  context '#start!' do
    let(:good_file) { File.open(Rails.root.join('README.md')) }
    let(:bad_file) { File.open(Rails.root.join('.ruby-version')) }
    before do
      klass.uploader = SpecUploaderClass
      klass.workflow = SpecUploaderWorkflow
      Sidekiq::Testing.inline!
    end

    after(:each) do
      Sidekiq::Testing.fake!
    end

    it 'returns validation errors' do
      expect_any_instance_of(SpecUploaderTask).not_to receive(:run)
      expect { klass.new.start!(bad_file) }
        .to raise_exception(/too small/)
    end

    it 'runs the workflow when the upload is valid' do
      expect(Sidekiq.logger).to receive(:fatal).with(/with options {:run=>"this"} and data \
{:foo=>"bar", :current_task=>"SpecUploaderTask"}/)
      klass.new(foo: :bar).start!(good_file)
    end
  end
end
