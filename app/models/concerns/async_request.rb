module AsyncRequest
  extend ActiveSupport::Concern
  include ActiveModel::Dirty
  include ActiveModel::Validations::Callbacks

  included do
    validates(:state, presence: true, inclusion: %w[success failed pending])
    validates(:response, presence: true, if: :success?)
    before_validation(:update_state_to_completed)
  end

  def success?
    state == 'success'
  end

  def update_state_to_completed
    response_changes = changes['response']

    self.state = 'success' if response_changed? && response_changes[0].blank? && response_changes[1].present?

    true
  end
end
