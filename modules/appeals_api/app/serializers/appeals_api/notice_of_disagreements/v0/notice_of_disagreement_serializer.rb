# frozen_string_literal: true

class AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementSerializer
  include JSONAPI::Serializer
  set_key_transform :camel_lower
  set_type :noticeOfDisagreement
  attributes :status
  attribute :code, if: proc { |nod| nod.status == 'error' }
  attribute :detail, if: proc { |nod| nod.status == 'error' }
  # These names are required by Lighthouse standards
  attribute :createDate, &:created_at
  attribute :updateDate, &:updated_at
end
