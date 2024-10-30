# frozen_string_literal: true

class Banner < ApplicationRecord
  self.table_name = 'banners'
  validates :entity_id, presence: true, uniqueness: true
  validates :entity_bundle, presence: true
  validates :headline, presence: true
  validates :alert_type, presence: true
  validates :content, presence: true
  validates :context, presence: true

  # Validations for boolean fields
  validates :show_close, inclusion: { in: [true, false] }
  validates :operating_status_cta, inclusion: { in: [true, false] }
  validates :email_updates_button, inclusion: { in: [true, false] }
  validates :find_facilities_cta, inclusion: { in: [true, false] }
  validates :limit_subpage_inheritance, inclusion: { in: [true, false] }
end
