# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      FORM_TYPE = '21-526EZ'

      def self.start(uuid)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid
        )
        batch.jobs do
          claim_id = get_claim_id(uuid)
          uploads = get_uploads(uuid)
          uploads.each_with_index { |u, i| perform_async(uuid, u[:guid], claim_id, i) }
        end
      end

      def self.get_claim_id(_uuid)
        nil
      end

      def self.get_uploads(_uuid)
        nil
      end

      def perform(uuid, _guid, _claim_id, count, index)
        logger.info('processing upload', user: uuid, component: 'EVSS', \
                                       form: FORM_TYPE, upload_count: count, upload_index: index)
        # TODO: process upload
        logger.info('upload processed', user: uuid, component: 'EVSS', \
                                      form: FORM_TYPE, upload_count: count, upload_index: index)
      rescue StandardError => error
        logger.error(
          'upload processing failed', user: uuid, component: 'EVSS', \
                                    form: FORM_TYPE, upload_count: count, upload_index: index, detail: error.message
        )
        raise error
      end

      def on_success(_status, options)
        uuid = options['uuid']
        logger.info('submit uploads success', user: uuid, component: 'EVSS', form: FORM_TYPE)
      end
    end
  end
end
