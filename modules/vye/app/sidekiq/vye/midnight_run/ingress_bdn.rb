# frozen_string_literal: true

module Vye
  class MidnightRun
    class IngressBdn
      include Sidekiq::Job
      sidekiq_options retry: 5

      def perform
        bdn_clone = Vye::BdnClone.create!(transact_date: Time.zone.today)
        bdn_clone_id = bdn_clone.id

        chunks = Vye::BatchTransfer::BdnChunk.build_chunks

        batch = Sidekiq::Batch.new
        batch.description = 'Ingress BDN Clone feed as chunked files'
        batch.on(:complete, "#{self.class.name}#on_complete", 'bdn_clone_id' => bdn_clone_id)
        batch.on(:success, "#{self.class.name}#on_success", 'bdn_clone_id' => bdn_clone_id)
        batch.jobs do
          chunks.each_with_index do |chunk, index|
            offset, block_size, filename = %i[offset block_size filename].map { |key| chunk.send(key) }
            IngressBdnChunk.perform_in((index * 5).seconds, bdn_clone_id, offset, block_size, filename)
          end
        end
      end

      def on_complete(status, options)
        bdn_clone_id = options['bdn_clone_id']

        message =
          if status.failures.zero?
            "#{self.class.name}: All chunks have ran for BdnClone(#{bdn_clone_id}), there were no failures."
          else
            <<~MESSAGE
              #{self.class.name}: All chunks have ran for BdnClone(#{bdn_clone_id}),
              there were #{status.failures} failure(s).
            MESSAGE
          end
        Rails.logger.info message
      end

      def on_success(_status, options)
        bdn_clone_id = options['bdn_clone_id']

        bdn_clone = BdnClone.find(bdn_clone_id)
        bdn_clone.update!(is_active: false)

        Rails.logger.info "#{self.class.name}: Ingress completed successfully for BdnClone(#{bdn_clone_id})"
      end
    end
  end
end
