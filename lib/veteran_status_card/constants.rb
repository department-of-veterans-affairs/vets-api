# frozen_string_literal: true

module VeteranStatusCard
  module Constants # rubocop:disable Metrics/ModuleLength
    SUPPORT_PHONE = '866-279-3677'
    SUPPORT_HOURS = 'Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'

    WARNING_STATUS = 'warning'
    ERROR_STATUS = 'error'

    STANDARD_ERROR_TITLE = "You're not eligible for a Veteran Status Card"
    STANDARD_ERROR_MESSAGE = [
      {
        type: 'text',
        value: 'Your record is missing information about your service history or discharge status.'
      },
      {
        type: 'text',
        value: "To fix the problem, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze

    DISHONORABLE_MESSAGE = [
      {
        type: 'text',
        value: 'To get a Veteran Status Card, you must have received an honorable discharge for at least ' \
               'one period of service.'
      },
      {
        type: 'text',
        value: "If you think this is incorrect, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    DISHONORABLE_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: DISHONORABLE_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    INELIGIBLE_SERVICE_MESSAGE = [
      {
        type: 'text',
        value: 'Your service history does not indicate an eligible period of service.'
      },
      {
        type: 'text',
        value: "If you think this is incorrect, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    INELIGIBLE_SERVICE_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: INELIGIBLE_SERVICE_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    UNKNOWN_SERVICE_MESSAGE = [
      {
        type: 'text',
        value: 'Your record is missing information about your service history or discharge status.'
      },
      {
        type: 'text',
        value: "To fix the problem, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    UNKNOWN_SERVICE_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: UNKNOWN_SERVICE_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    EDIPI_NO_PNL_MESSAGE = [
      {
        type: 'text',
        value: "There's a problem with your records."
      },
      {
        type: 'text',
        value: "To fix the problem, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    EDIPI_NO_PNL_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: EDIPI_NO_PNL_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    CURRENTLY_SERVING_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: STANDARD_ERROR_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    ERROR_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: STANDARD_ERROR_MESSAGE,
      status: ERROR_STATUS
    }.freeze

    SOMETHING_WENT_WRONG_TITLE = "We're sorry, something went wrong"
    SOMETHING_WENT_WRONG_MESSAGE = [
      {
        type: 'text',
        value: 'Something went wrong on our end. Please try again later.'
      },
      {
        type: 'text',
        value: "If this problem persists, contact VA.gov technical support. We're open #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    SOMETHING_WENT_WRONG_RESPONSE = {
      title: SOMETHING_WENT_WRONG_TITLE,
      message: SOMETHING_WENT_WRONG_MESSAGE,
      status: ERROR_STATUS
    }.freeze
  end
end
