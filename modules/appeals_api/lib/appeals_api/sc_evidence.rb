# frozen_string_literal: true

module AppealsApi
  ScEvidence = Struct.new(:type, :attributes) do
    def location
      attributes['locationAndName']
    end

    def dates_day_format
      evidence_dates = attributes['evidenceDates']

      return [''] if evidence_dates.blank?

      evidence_dates.map do |hash|
        if hash['startDate'] == hash['endDate']
          hash['startDate']
        else
          "#{hash['startDate']} to #{hash['endDate']}"
        end
      end
    end

    def dates_month_format
      evidence_dates = attributes['evidenceDates']

      return [''] if evidence_dates.blank?

      evidence_dates.map do |hash|
        "#{Date.parse(hash['startDate']).strftime('%m-%Y')} to #{Date.parse(hash['endDate']).strftime('%m-%Y')}"
      end
    end

    def no_treatment_date
      attributes['noTreatmentDates']
    end
  end
end
