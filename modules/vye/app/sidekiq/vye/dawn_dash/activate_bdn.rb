# frozen_string_literal: true

module Vye
  class DawnDash
    class ActivateBdn
      class BndCloneNotFound < StandardError; end
      include Sidekiq::Job
      sidekiq_options retry: 8, unique_for: 12.hours

      private

      def confirm_injest!
        raise BndCloneNotFound unless BdnClone.injested?

        Rails.logger.info "#{self.class.name}: proceeding with activation"
      rescue BndCloneNotFound
        Rails.logger.error "#{self.class.name}: nothing found to activate"
        raise
      end

      def perform_activation!
        BdnClone.activate_injested!
        Rails.logger.info "#{self.class.name}: activation complete"
      rescue
        Rails.logger.error "#{self.class.name}: there was a problem during activation"
        raise
      end

      public

      def perform
        confirm_injest!
        perform_activation!
        EgressUpdates.perform_async
      end
    end
  end
end
