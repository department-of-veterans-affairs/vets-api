# frozen_string_literal: true

module VeteranVerification
  module Constants
    STATSD_VET_VERIFICATION_TOTAL_KEY = 'api.lighthouse.vet_verification_status.total'
    STATSD_VET_VERIFICATION_FAIL_KEY = 'api.lighthouse.vet_verification_status.fail'

    ERROR_MESSAGE = [
      'We’re sorry. There’s a problem with our system. We can’t show your Veteran status card right now. Try again ' \
      'later.'
    ].freeze
    NOT_FOUND_MESSAGE = [
      'We’re sorry. There’s a problem with your discharge status records. We can’t provide a Veteran status ' \
      'card for you right now.',
      'To fix the problem with your records, call the Defense Manpower Data Center at 800-538-9552 (TTY: 711).' \
      ' They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
    ].freeze
    NOT_ELIGIBLE_MESSAGE = [
      'Our records show that you’re not eligible for a Veteran status card. To get a Veteran status card, you ' \
      'must have received an honorable discharge for at least one period of service.',
      'If you think your discharge status is incorrect, call the Defense Manpower Data Center at 800-538-9552 ' \
      '(TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
    ].freeze

    ERROR_MESSAGE_UPDATED = [
      'We’re sorry. Try to view your Veteran status card again later.'
    ].freeze
    NOT_FOUND_MESSAGE_UPDATED = [
      'We’re sorry. To fix the problem with your records, call the Defense Manpower Data Center ' \
      ' at 800-538-9552 (TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
    ].freeze
    NOT_ELIGIBLE_MESSAGE_UPDATED = [
      'To get a Veteran status card, you must have received an honorable discharge for at least one period ' \
      ' of service.',
      'If you think your discharge status is incorrect, call the Defense Manpower Data Center at 800-538-9552 ' \
      '(TTY: 711). They’re open Monday through Friday, 8:00 a.m. to 8:00 p.m. ET.'
    ].freeze

    ERROR_MESSAGE_TITLE = 'Something went wrong'
    NOT_FOUND_MESSAGE_TITLE = 'There’s a problem with your discharge status records'
    NOT_ELIGIBLE_MESSAGE_TITLE = 'You’re not eligible for a Veteran Status Card'

    ERROR_MESSAGE_STATUS = 'error'
    NOT_FOUND_MESSAGE_STATUS = 'warning'
    NOT_ELIGIBLE_MESSAGE_STATUS = 'warning'
  end
end
