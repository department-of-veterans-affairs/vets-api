# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Dental Indicator data
    #
    # @!attribute separation_date
    #   @return [Date] date on which a member separated from a specific service and component.
    #     The data is received daily from DD 214 data feeds. The data is required under the
    #     iEHR program and electronic DD214 initiative. It will be made optionally available
    #     to customers requiring this element as part of a DD214 electronic inquiry.
    # @!attribute dental_indicator
    #   @return [String] This data element indicates whether the member was provided a
    #     complete dental examination and all appropriate dental services and treatment within
    #     90 days prior to separating from Active Duty. The data is received daily from DD 214
    #     data feeds. This field is Box 17 on DD Form 214, Aug 2009 version. The data is
    #     required under the iEHR program and electronic DD214 initiative. It will be made
    #     optionally available to customers requiring this element as part of a DD214
    #     electronic inquiry.
    #       N => No
    #       Y => Yes
    #       Z => Unknown
    class DentalIndicator
      include Virtus.model

      attribute :separation_date, Date
      attribute :dental_indicator, String
    end
  end
end
