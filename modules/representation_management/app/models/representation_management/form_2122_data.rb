# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    service_organization_attrs = %i[
      service_organization_name
      service_organization_representative_name
      service_organization_job_title
      service_organization_email
      service_organization_appointment_date
    ]

    attr_reader service_organization_attrs

    validates :service_organization_name, presence: true
  end
end
