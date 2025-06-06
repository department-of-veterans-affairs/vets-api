# frozen_string_literal: true

require 'vets/model'
require 'va_profile/models/email'
##
# Models Prescription notification preference
#
# @!attribute email_address
#   @return [String]
# @!attribute rx_flag
#   @return [Boolean]
#
class PrescriptionPreference
  include Vets::Model

  attribute :email_address, String
  attribute :rx_flag, Bool

  validates :rx_flag, inclusion: { in: [true, false] }
  validates(
    :email_address,
    presence: true,
    format: { with: VAProfile::Models::Email::VALID_EMAIL_REGEX },
    length: { maximum: 255, minimum: 6 }
  )

  ##
  # Build the object for MHV
  #
  # @raise [Common::Exceptions::ValidationErrors] if invalid attributes
  # @return [Hash]
  #
  def mhv_params
    raise Common::Exceptions::ValidationErrors, self unless valid?

    { email_address:, rx_flag: }
  end

  ##
  # Compute a hex-formatted digest of the attributes to be used as an ID
  #
  # @return [String]
  #
  def id
    Digest::SHA256.hexdigest(instance_variable_get(:@original_attributes).to_json)
  end
end
