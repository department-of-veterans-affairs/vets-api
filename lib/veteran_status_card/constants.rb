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
        value: "To fix the problem, contact VA.gov technical support. We're here #{SUPPORT_HOURS}"
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
        value: "Your service history and discharge status don't meet the requirements for a Veteran Status Card."
      },
      {
        type: 'text',
        value: "If you think this is incorrect, call us. We're here #{SUPPORT_HOURS}"
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
        value: "Your service doesn't meet the requirements for a Veteran Status Card."
      },
      {
        type: 'text',
        value: "If you think this is incorrect, call us. We're here #{SUPPORT_HOURS}"
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

    UNKNOWN_ELIGIBILITY_TITLE = "We don't know if you're eligible for this card"
    UNKNOWN_ELIGIBILITY_MESSAGE = [
      {
        type: 'text',
        value: 'Your record is missing information about your service history or discharge status.'
      },
      {
        type: 'text',
        value: "To fix the problem, call us. We're here #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    UNKNOWN_ELIGIBILITY_RESPONSE = {
      title: UNKNOWN_ELIGIBILITY_TITLE,
      message: UNKNOWN_ELIGIBILITY_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    CURRENTLY_SERVING_MESSAGE = [
      {
        type: 'text',
        value: "You can't get a Veteran Status Card if you're currently serving."
      },
      {
        type: 'text',
        value: "If you have a previous period of service, call us. We're here #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    CURRENTLY_SERVING_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: CURRENTLY_SERVING_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    UNCAUGHT_ERROR_TITLE = "This page isn't working right now"
    UNCAUGHT_ERROR_MESSAGE = [
      {
        type: 'text',
        value: "We're sorry. Something went wrong on our end. Refresh this page or try again later."
      }
    ].freeze
    UNCAUGHT_ERROR_RESPONSE = {
      title: UNCAUGHT_ERROR_TITLE,
      message: UNCAUGHT_ERROR_MESSAGE,
      status: WARNING_STATUS
    }.freeze

    SOMETHING_WENT_WRONG_TITLE = 'Something went wrong'
    SOMETHING_WENT_WRONG_MESSAGE = [
      {
        type: 'text',
        value: "We're sorry. Something went wrong on our end. Try again later."
      }
    ].freeze
    SOMETHING_WENT_WRONG_RESPONSE = {
      title: SOMETHING_WENT_WRONG_TITLE,
      message: SOMETHING_WENT_WRONG_MESSAGE,
      status: ERROR_STATUS
    }.freeze

    PERSON_NOT_FOUND_MESSAGE = [
      {
        type: 'text',
        value: 'Your records are missing from the system.'
      },
      {
        type: 'text',
        value: "To fix the issue, call us. We're here #{SUPPORT_HOURS}"
      },
      {
        type: 'phone',
        value: SUPPORT_PHONE,
        tty: true
      }
    ].freeze
    PERSON_NOT_FOUND_RESPONSE = {
      title: STANDARD_ERROR_TITLE,
      message: PERSON_NOT_FOUND_MESSAGE,
      status: WARNING_STATUS
    }.freeze
  end
end
