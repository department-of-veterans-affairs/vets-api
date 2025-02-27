# frozen_string_literal: true

module Form1095
  class Delete1095BsJob
    include Sidekiq::Job

    def perform
      Form1095B.where('tax_year < ?', Form1095B.current_tax_year).in_batches do |batch|
        batch.delete_all
      end
    end
  end
end
