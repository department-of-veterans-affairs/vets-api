# frozen_string_literal: true
class FileUpload
  class_attribute :uploader
  class_attribute :workflow
  attr_accessor :options, :errors

  def initialize(**args)
    raise 'Need a uploader!' unless uploader && uploader < Shrine
    raise 'Need a post upload workflow!' unless workflow && workflow < Workflow::Base
    @options = args
    @attacher ||= uploader::Attacher.new(InternalAttachment.new(args), :file)
  end

  def start!(file, trace: nil)
    # run the shrine upload process.
    @attacher.assign(file)
    fail! unless @attacher.errors.blank?
    # Pass in the Shrine-serialized uploaded file to the workflow
    w = workflow.new(@attacher, @options)
    job_id = w.start!(trace: trace)
    { job_id: job_id, file: @attacher.get }
  end

  private

  def fail!
    error = Struct.new(:key, :message)
    @errors = @attacher.errors.map do |e|
      error.new(:file, e)
    end
    raise Common::Exceptions::UploadErrors, self
  end

  def uploader
    self.class.uploader
  end

  def workflow
    self.class.workflow
  end
end
