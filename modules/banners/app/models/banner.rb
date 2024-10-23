# frozen_string_literal: true

class Banner < ApplicationRecord
  self.table_name = 'banners'
  validates :entity_id, presence: true, uniqueness: true
  validates :entity_bundle, presence: true
  validates :headline, presence: true
  validates :alert_type, presence: true
  validates :show_close, presence: true
  validates :content, presence: true
  validates :context, presence: true
  validates :operating_status_cta, presence: true
  validates :email_updates_button, presence: true
  validates :find_facilities_cta, presence: true
  validates :limit_subpage_inheritance, presence: true
end
