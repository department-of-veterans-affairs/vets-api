# frozen_string_literal: true

require 'sidekiq/form526_historical_data_exporter/exporter'

module Sidekiq
  module Form526HistoricalDataExporter
    class Queuer
      # date_from must be in format MM/DD/YYYY
      def initialize(chunk_size, batch_size, date_from, date_to = nil)
        @chunk_size = chunk_size
        @batch_size = batch_size
        @date_from = Date.strptime(date_from, '%m/%d/%Y')
        @date_to = Date.strptime(date_to, '%m/%d/%Y') if date_to.present?
      end

      def export
        chunk_submissions.each do |chunk|
          data_job_wrapper(chunk)
        end
      end

      def chunk_submissions
        query = if @date_to.present?
                  Form526Submission.where('created_at >= ? AND created_at <= ?', @date_from, @date_to)
                else
                  Form526Submission.where('created_at >= ?', @date_from)
                end
        query.pluck(:id).each_slice(@chunk_size)
      end

      def data_job_wrapper(chunk)
        Form526BackgroundDataJob.perform_async(@batch_size, chunk.first, chunk.last)
      end
    end

    class Form526BackgroundDataJob
      include Sidekiq::Worker

      def perform(batch_size, start_id, end_id)
        Exporter.new(batch_size, start_id, end_id).process!
      end
    end
  end
end
