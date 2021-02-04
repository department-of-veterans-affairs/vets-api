# frozen_string_literal: true

class AppealsApi::NoticeOfDisagreementSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :camel_lower
  attributes :status, :updated_at, :created_at, :form_data
  set_type :noticeOfDisagreement
end
