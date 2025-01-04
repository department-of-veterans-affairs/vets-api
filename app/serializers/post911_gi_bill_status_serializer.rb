# frozen_string_literal: true

class Post911GIBillStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attribute :first_name
  attribute :last_name
  attribute :name_suffix
  attribute :date_of_birth
  attribute :va_file_number
  attribute :regional_processing_office
  attribute :eligibility_date
  attribute :delimiting_date
  attribute :percentage_benefit
  attribute :original_entitlement
  attribute :used_entitlement
  attribute :remaining_entitlement
  attribute :entitlement_transferred_out, if: proc { |_record| Flipper.enabled?(:sob_updated_design) }
  attribute :active_duty
  attribute :veteran_is_eligible
  attribute :enrollments
end
