# frozen_string_literal: true

module RepresentationManagement
  class PowerOfAttorneyRequestEmailData
    include ActiveModel::Model

    attr_accessor :pdf_data

    validates :pdf_data, presence: true

    def first_name
      pdf_data.send("#{submitter}_first_name")
    end

    def last_name
      pdf_data.send("#{submitter}_last_name")
    end

    def submit_date
      base_date.strftime('%B %d, %Y')
    end

    def submit_time
      base_time
    end

    def expiration_date
      base_date + 60.days.strftime('%B %d, %Y')
    end

    def expiration_time
      base_time
    end

    def representative_name
      if pdf_data.representative.present?
        pdf_data.representative.full_name.strip
      else
        pdf_data.organization.name.strip
      end
    end

    private

    def base_date
      Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
    end

    def base_time
      base_date.strftime('%I:%M %p')
    end

    def submitter
      @submitter ||= find_submitter
    end

    def find_submitter
      pdf_data.claimant_first_name.present? ? 'claimant' : 'veteran'
    end
  end
end
