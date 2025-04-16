# frozen_string_literal: true

require 'active_model'

module Kafka
  class FormTrace
    include ActiveModel::API
    include ActiveModel::Attributes

    SYSTEM_NAMES = %w[Lighthouse CMP VBMS VA_gov VES].freeze
    SUBMISSION_NAMES = %w[F1010EZ F527EZ].freeze
    STATES = %w[received sent completed error].freeze

    def initialize(attributes = {})
      super
      self.submission_name = truncate_form_id(submission_name) if submission_name
    end

    attribute :prior_id, :string
    attribute :current_id, :string
    attribute :next_id, :string
    attribute :icn, :string
    attribute :vasi_id, :string
    attribute :system_name, :string
    attribute :submission_name, :string
    attribute :state, :string
    attribute :timestamp, :string
    attribute :additional_ids, array: true, default: []

    validates :current_id, :vasi_id, :system_name, :submission_name, :state, :timestamp, presence: true
    validates :system_name, inclusion: { in: SYSTEM_NAMES }
    validates :submission_name, inclusion: { in: SUBMISSION_NAMES }
    validates :state, inclusion: { in: STATES }

    def truncate_form_id(form_id)
      return form_id if SUBMISSION_NAMES.include?(form_id)

      dash_index = form_id.index('-')
      return "F#{form_id}" if dash_index.nil?

      "F#{form_id[(dash_index + 1)..]}"
    end
  end
end
