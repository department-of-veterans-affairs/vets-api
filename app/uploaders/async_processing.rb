module AsyncProcessing
  extend ActiveSupport::Concern

  included do
    after(:store, :process_file)
  end

  def process_file
    ProcessFileJob.perform_async(PROCESSING_CLASS, store_dir, filename)
  end
end
