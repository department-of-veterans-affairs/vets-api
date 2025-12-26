# frozen_string_literal: true

module VeteranStatusCard
  module Constants
    STANDARD_ERROR_TITLE = "You're not eligible for a Veteran Status Card."

    STANDARD_ERROR_MESSAGE = [
      'Your record is missing information about your service history or discharge status.',
      "To fix the problem, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. \
      to 8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze

    DISHONORABLE_TITLE = STANDARD_ERROR_TITLE
    DISHONORABLE_MESSAGE = [
      'To get a Veteran Status Card, you must have received an honorable discharge for at least one period of service.',
      "If you think this is incorrect, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. \
       to 8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze
    DISHONORABLE_STATUS = 'warning'
    DISHONORABLE_RESPONSE = {
      title: DISHONORABLE_TITLE,
      message: DISHONORABLE_MESSAGE,
      status: DISHONORABLE_STATUS
    }.freeze

    INELIGIBLE_SERVICE_TITLE = STANDARD_ERROR_TITLE
    INELIGIBLE_SERVICE_MESSAGE = [
      'Your service history does not indicate an eligible period of service.',
      "If you think this is incorrect, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. \
      to 8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze
    INELIGIBLE_SERVICE_STATUS = 'warning'
    INELIGIBLE_SERVICE_RESPONSE = {
      title: INELIGIBLE_SERVICE_TITLE,
      message: INELIGIBLE_SERVICE_MESSAGE,
      status: INELIGIBLE_SERVICE_STATUS
    }.freeze

    UNKNOWN_SERVICE_TITLE = STANDARD_ERROR_TITLE
    UNKNOWN_SERVICE_MESSAGE = [
      'Your record is missing information about your service history or discharge status.',
      "To fix the problem, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. \
      to 8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze
    UNKNOWN_SERVICE_STATUS = 'warning'
    UNKNOWN_SERVICE_RESPONSE = {
      title: UNKNOWN_SERVICE_TITLE,
      message: UNKNOWN_SERVICE_MESSAGE,
      status: UNKNOWN_SERVICE_STATUS
    }.freeze

    EDIPI_NO_PNL_TITLE = STANDARD_ERROR_TITLE
    EDIPI_NO_PNL_MESSAGE = [
      "There's a problem with your records.",
      "To fix the problem, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. to \
      8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze
    EDIPI_NO_PNL_STATUS = 'warning'
    EDIPI_NO_PNL_RESPONSE = {
      title: EDIPI_NO_PNL_TITLE,
      message: EDIPI_NO_PNL_MESSAGE,
      status: EDIPI_NO_PNL_STATUS
    }.freeze

    CURRENTLY_SERVING_TITLE = STANDARD_ERROR_TITLE
    CURRENTLY_SERVING_MESSAGE = STANDARD_ERROR_MESSAGE
    CURRENTLY_SERVING_STATUS = 'warning'
    CURRENTLY_SERVING_RESPONSE = {
      title: CURRENTLY_SERVING_TITLE,
      message: CURRENTLY_SERVING_MESSAGE,
      status: CURRENTLY_SERVING_STATUS
    }.freeze

    ERROR_TITLE = STANDARD_ERROR_TITLE
    ERROR_MESSAGE = STANDARD_ERROR_MESSAGE
    ERROR_STATUS = 'error'
    ERROR_RESPONSE = {
      title: ERROR_TITLE,
      message: ERROR_MESSAGE,
      status: ERROR_STATUS
    }.freeze

    SOMETHING_WENT_WRONG_TITLE = "We're sorry, something went wrong."
    SOMETHING_WENT_WRONG_MESSAGE = [
      'Something went wrong on our end. Please try again later.',
      "If this problem persists, contact VA.gov technical support. We're open Monday through Friday, 8:00 a.m. to \
      8:00 p.m. E.T.",
      '866-279-3677',
      'TTY: 711'
    ].freeze
    SOMETHING_WENT_WRONG_STATUS = 'error'
    SOMETHING_WENT_WRONG_RESPONSE = {
      title: SOMETHING_WENT_WRONG_TITLE,
      message: SOMETHING_WENT_WRONG_MESSAGE,
      status: SOMETHING_WENT_WRONG_STATUS
    }.freeze
  end
end
