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

  scope :by_path, lambda { |path|
    subpage_path_reduced_to_root = path.match(%r{^/[^/]*}).to_s
    subpage_match = where('banners.path = ? AND limit_subpage_inheritance = ?', subpage_path_reduced_to_root, false)
    exact_match = where('banners.path = ?', path)

    subpage_match.or(exact_match)
  }
end
