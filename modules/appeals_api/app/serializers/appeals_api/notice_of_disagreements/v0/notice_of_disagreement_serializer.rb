# frozen_string_literal: true

class AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementSerializer
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  set_type :noticeOfDisagreement
  attributes :status
  attribute :code, if: proc { |nod| nod.status == 'error' }

  attribute :final_status, if: proc { |_, _|
    # The final_status will be serialized only if the decision_reviews_final_status_field flag is enabled
    Flipper.enabled?(:decision_reviews_final_status_field)
  } do |object, _|
    object.upload_submission.in_final_status?
  end

  attribute :detail, if: proc { |nod| nod.status == 'error' }
  # These names are required by Lighthouse standards
  attribute :createDate, &:created_at
  attribute :updateDate, &:updated_at
end
