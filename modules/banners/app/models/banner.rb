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

  # Returns banners for a given path and banner bundle type.
  scope :by_path_and_type, lambda { |path, type|
    # Filter by entity_bundle
    bundle_condition = arel_table[:entity_bundle].eq(type)

    # JSONB containment conditions using @>.
    operating_system_condition = 'context @> ?'
    home_condition = 'context @> ?'

    # Use ActiveRecord's `where` with an OR clause for the JSONB paths.
    where(bundle_condition)
      .where("#{operating_system_condition} OR #{home_condition}",
             [{ entity: { entityUrl: { path: path } } }].to_json,
             [{ entity: { fieldOffice: { entity: { entityUrl: { path: path } } } } }].to_json)
  }
end
