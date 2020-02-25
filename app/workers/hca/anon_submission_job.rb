# frozen_string_literal: true

module HCA
  class AnonSubmissionJob < BaseSubmissionJob
    sidekiq_options retry: false
  end
end
