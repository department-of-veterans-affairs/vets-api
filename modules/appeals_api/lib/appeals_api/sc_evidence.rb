# frozen_string_literal: true

module AppealsApi
  ScEvidence = Struct.new(:type, :attributes) do
    def location
      attributes['locationAndName']
    end

    def dates
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
  end
end
