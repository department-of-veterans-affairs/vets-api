# frozen_string_literal: true

module AsyncProcessing
  extend ActiveSupport::Concern

  included do
    after(:store, :process_file)
  end

  def process_file(_file)
    ProcessFileJob.perform_async(self.class::PROCESSING_CLASS.to_s, store_dir, filename)
  end
end
