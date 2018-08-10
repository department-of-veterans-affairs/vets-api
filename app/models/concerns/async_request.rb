# frozen_string_literal: true

module AsyncRequest
  extend ActiveSupport::Concern
  include ActiveModel::Validations::Callbacks

  included do
    validates(:state, presence: true, inclusion: %w[success failed pending])
    validates(:response, presence: true, if: :success?)
  end

  def success?
    state == 'success'
  end
end
