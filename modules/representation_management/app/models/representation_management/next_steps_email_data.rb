# frozen_string_literal: true

module RepresentationManagement
  class NextStepsEmailData
    include ActiveModel::Model

    next_steps_email_attrs = %i[
      email_address
      first_name
      form_name
      form_number
      representative_type
      representative_name
      representative_address
    ]

    attr_accessor(*[next_steps_email_attrs].flatten)

    validates :email_address, presence: true
    validates :first_name, presence: true
    validates :form_name, presence: true
    validates :form_number, presence: true
    validates :representative_type, presence: true
    validates :representative_name, presence: true
    validates :representative_address, presence: true
  end
end
