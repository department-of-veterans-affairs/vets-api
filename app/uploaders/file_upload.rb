# frozen_string_literal: true
class FileUpload
  attr_accessor :options
  class << self
    def uploader(uploader = nil)
      @uploader ||= uploader
    end

    def workflow(workflow = nil)
      @workflow ||= workflow
    end
  end

  def initialize(**args)
    raise 'Need a uploader!' unless uploader && uploader < Shrine
    raise 'Need a post upload workflow!' unless workflow && workflow < Workflow::Base
    @options = args
    @attacher ||= uploader::Attacher.new(InternalAttachment.new(args), :file)
  end

  def start!(file, trace: nil)
    # run the shrine upload process.
    @attacher.assign(file)
    raise ArgumentError, @attacher.errors.join(',') unless @attacher.errors.blank?
    # Pass in the Shrine-serialized uploaded file to the workflow
    w = workflow.new(@attacher, @options)
    w.start!(trace: trace)
  end

  private

  def uploader
    self.class.uploader
  end

  def workflow
    self.class.workflow
  end
end
