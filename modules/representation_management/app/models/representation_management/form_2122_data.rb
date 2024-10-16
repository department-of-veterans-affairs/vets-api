# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    def organization_name
      org = Veteran::Service::Organization.find_by(poa: @organization_name)
      @organization_name = org&.name
    end

    attr_writer :organization_name

    validates :organization_name, presence: true # This will actually be an id of an organization
  end
end
