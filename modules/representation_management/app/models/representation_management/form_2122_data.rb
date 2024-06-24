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

    validates :service_organization_name, presence: true

    attr_accessor service_organization_attrs
  end
end
