# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressTims
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        return if Flipper.enabled?(:disable_bdn_processing)

        if Vye::CloudTransfer.holiday?
          Rails.logger.info("Vye::MidnightRun::IngressTims: holiday detected, job run at: #{Time.zone.now}")
          return
        end

        Vye::PendingDocument.delete_all

        chunks = BatchTransfer::TimsChunk.build_chunks

        batch = Sidekiq::Batch.new
        batch.description = 'Ingress TIMS feed as chunked files'
        batch.on(:complete, "#{self.class.name}#on_complete")
        batch.on(:success, "#{self.class.name}#on_success")
        batch.jobs do
          chunks.each_with_index do |chunk, index|
            offset, block_size, filename = %i[offset block_size filename].map { |key| chunk.send(key) }
            IngressTimsChunk.perform_in((index * 5).seconds, offset, block_size, filename)
          end
        end
      end

      def on_complete(status, _options="")
        message =
          if status.failures.zero?
            "#{self.class.name}: All chunks have ran for TIMS feed, there were no failures."
          else
            <<~MESSAGE
              #{self.class.name}: All chunks have ran for TIMS feed,
              there were #{status.failures} failure(s).
            MESSAGE
          end
        Rails.logger.info message
      end

      def on_success(_status, _options="")
        Rails.logger.info "#{self.class.name}: Ingress completed successfully for TIMS feed"
      end
    end
  end
end
