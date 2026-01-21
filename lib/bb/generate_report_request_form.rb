# frozen_string_literal: true

require 'vets/model'
require 'vets/shared_logging'

module BB
  class GenerateReportRequestForm
    include Vets::Model
    include Vets::SharedLogging

    ELIGIBLE_DATA_CLASSES = %w[ seiactivityjournal seiallergies seidemographics
                                familyhealthhistory seifoodjournal healthcareproviders healthinsurance
                                seiimmunizations labsandtests medicalevents militaryhealthhistory
                                seimygoalscurrent seimygoalscompleted treatmentfacilities
                                vitalsandreadings prescriptions medications vaallergies
                                vaadmissionsanddischarges futureappointments pastappointments
                                vademographics vaekg vaimmunizations vachemlabs vaprogressnotes
                                vapathology vaproblemlist varadiology vahth wellness dodmilitaryservice ].freeze

    attribute :from_date, Vets::Type::UTCTime
    attribute :to_date, Vets::Type::UTCTime
    attribute :data_classes, String, array: true, default: []

    attr_reader :client

    validates :from_date, :to_date, date: true
    # TODO: leaving this validation out for now, will test and see if it is required or if
    # MHV error is preferable.
    # validates :from_date, date: { before: :to_date, message: 'must be before to date' }
    validates :data_classes, presence: true
    # TODO: eventually this should be reenabled,
    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    # validate  :data_classes_belongs_to_eligible_data_classes
    def overridden_data_classes
      eligible_data_classes & data_classes
    end

    def initialize(client, attributes = {})
      super(attributes)
      @client = client
    end

    # TODO: change this back to data_classes when hack can be properly removed.
    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    def params
      { from_date: from_date.try(:httpdate), to_date: to_date.try(:httpdate), data_classes: overridden_data_classes }
    end

    private

    def eligible_data_classes
      @eligible_data_classes ||= client.get_eligible_data_classes.members.map(&:name)
    end

    # TODO: uncomment to re-enable this validation
    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    # def data_classes_belongs_to_eligible_data_classes
    #   ineligible_data_classes = data_classes - eligible_data_classes
    #   if ineligible_data_classes.any?
    #     log_message_to_sentry('Health record ineligible classes', :info,
    #                           extra_context: { data_classes: data_classes,
    #                                            eligible_data_classes: eligible_data_classes })
    #     log_message_to_rails('Health record ineligible classes', :info)
    #     errors.add(:base, "Invalid data classes: #{ineligible_data_classes.join(', ')}")
    #   end
    # end
  end
end
