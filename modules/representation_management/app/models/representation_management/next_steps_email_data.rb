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

    attr_accessor(*next_steps_email_attrs)

    validates :email_address, presence: true
    validates :first_name, presence: true
    validates :form_name, presence: true
    validates :form_number, presence: true
    validates :representative_type, presence: true
    validates :representative_type, inclusion: { in: AccreditedIndividual.individual_types.keys }
    validates :representative_name, presence: true
    validates :representative_address, presence: true

    def representative_type_humanized
      @representative_type_humanized ||= representative_type.humanize.titleize
    end
  end
end
