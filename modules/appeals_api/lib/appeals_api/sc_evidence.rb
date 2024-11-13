# frozen_string_literal: true

module AppealsApi
  ScEvidence = Struct.new(:type, :attributes) do
    def location
      attributes['locationAndName']
    end

    def dates(month_format: false)
      evidence_dates = attributes['evidenceDates']

      return [''] if evidence_dates.blank?

      evidence_dates.map do |hash|
        if (hash['startDate'] == hash['endDate']) && !month_format
          hash['startDate']
        elsif !month_format
          "#{hash['startDate']} to #{hash['endDate']}"
        else
          start_yyyy_mm = hash['startDate'].split('-').take(2).reverse.join('-')
          end_yyyy_mm = hash['endDate'].split('-').take(2).reverse.join('-')
          "#{start_yyyy_mm} to #{end_yyyy_mm}"
        end
      end
    end
  end
end
