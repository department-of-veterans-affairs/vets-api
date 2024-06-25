# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    organization_attrs = %i[
      organization_name
      organization_representative_name
      organization_job_title
      organization_email
      organization_appointment_date
    ]

    attr_reader organization_attrs

    validates :organization_name, presence: true
  end
end
