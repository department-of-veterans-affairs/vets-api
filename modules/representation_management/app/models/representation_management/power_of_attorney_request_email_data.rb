# frozen_string_literal: true

module RepresentationManagement
  class PowerOfAttorneyRequestEmailData
    include ActiveModel::Model

    attr_accessor :form_data

    validates :form_data, presence: true

    def email_address
      form_data.send("#{submitter}_email")
    end

    def first_name
      form_data.send("#{submitter}_first_name")
    end

    def last_name
      form_data.send("#{submitter}_last_name")
    end

    def submit_date
      base_date.strftime('%B %d, %Y')
    end

    def expiration_date
      (base_date + 60.days).strftime('%B %d, %Y')
    end

    def representative_name
      if form_data.representative.present?
        form_data.representative.full_name.strip
      else
        form_data.organization.name.strip
      end
    end

    private

    def base_date
      Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
    end

    def submitter
      @submitter ||= find_submitter
    end

    def find_submitter
      form_data.claimant_first_name.present? ? 'claimant' : 'veteran'
    end
  end
end
