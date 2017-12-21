# frozen_string_literal: true
class Feedback
  extend ActiveModel::Callbacks

  include ActiveModel::Validations
  include Virtus.model(nullify_blank: true)

  define_model_callbacks :initialize, only: :after
  after_initialize :sanitize_sensitive_data

  # source: https://stackoverflow.com/a/27194235
  EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

  # source https://stackoverflow.com/a/20386405
  SSN_REGEX = /(\d{3})[^\d]?\d{2}[^\d]?\d{4}/

  attribute :target_page, String
  attribute :description, String
  attribute :owner_email, String

  validates :target_page, presence: true
  validates :description, presence: true

  def initialize(attributes ={})
    run_callbacks :initialize do
      super(attributes)
    end
  end

  private

  def sanitize_sensitive_data
    return if @description.nil?
    @description.gsub!(EMAIL_REGEX, '[FILTERED EMAIL]')
    @description.gsub!(SSN_REGEX, '[FILTERED SSN]')
  end
end
