# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

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

          logger.info('submit uploads start', user: uuid, component: 'EVSS', \
                                              form: '21-526EZ', upload_count: uploads.count)
          uploads.each_with_index { |u, i| perform_async(uuid, u.guid, claim_id, i) }
        end
      end
    end

    def perform(uuid, _guid, _claim_id, count, index)
      logger.info('processing upload', user: uuid, component: 'EVSS', \
                                       form: '21-526EZ', upload_count: count, upload_index: index)
      # TODO: process upload
      logger.info('upload processed', user: uuid, component: 'EVSS', \
                                      form: '21-526EZ', upload_count: count, upload_index: index)
    rescue StandardError => error
      logger.error(
        'upload processing failed', user: uuid, component: 'EVSS', \
                                    form: '21-526EZ', upload_count: count, upload_index: index, detail: error.message
      )
      raise error
    end

    def on_success(_status, options)
      uuid = options['uuid']
      logger.info('submit uploads success', user: uuid, component: 'EVSS', form: '21-526EZ')
    end

    def get_claim_id(_uuid) end

    def get_uploads(_uuid) end
  end
end
