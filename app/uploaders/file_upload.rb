# frozen_string_literal: true
class FileUpload
  class_attribute :uploader
  class_attribute :workflow
  attr_accessor :options

  def initialize(**args)
    raise 'Need a uploader!' unless uploader && uploader < Shrine
    raise 'Need a post upload workflow!' unless workflow && workflow < Workflow::Base
    @options = args
    @attacher ||= uploader::Attacher.new(InternalAttachment.new(args), :file)
  end

  def start!(file, trace: nil)
    # run the shrine upload process.
    if file.is_a? Shrine::UploadedFile
      @attacher.set(file)
    else
      @attacher.assign(file)
    end
    raise ArgumentError, @attacher.errors.join(',') unless @attacher.errors.blank?
    # Pass in the Shrine-serialized uploaded file to the workflow
    w = workflow.new(@attacher, @options)
    job_id = w.start!(trace: trace)
    { job_id: job_id, file: @attacher.get }
  end

  private

  def uploader
    self.class.uploader
  end

  def workflow
    self.class.workflow
  end
end
