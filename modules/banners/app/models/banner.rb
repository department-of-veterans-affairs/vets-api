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
    normalized_path = path.sub(%r{^/?}, '')

    # Direct path matches.
    exact_path_conditions = where('banners.context @> ?',
                                  [
                                    { entity:
                                     { entityUrl:
                                      { path: } } }
                                  ].to_json)
                            .or(where('banners.context @> ?',
                                      [
                                        { entity:
                                          { fieldOffice:
                                            { entity:
                                              { entityUrl:
                                                { path: } } } } }
                                      ].to_json))

    # Subpage inheritance check: Matches on any `entityUrl` where `limit_subpage_inheritance` is false.
    subpage_pattern = "/#{normalized_path.split('/').first}"
    subpage_condition = where('banners.context @> ?',
                              [
                                { entity:
                                  { entityUrl:
                                  { path: subpage_pattern } } }
                              ].to_json)
                        .or(where('banners.context @> ?',
                                  [
                                    { entity:
                                      { fieldOffice:
                                        { entity:
                                          { entityUrl:
                                            { path: subpage_pattern } } } } }
                                  ].to_json))
                        .where(limit_subpage_inheritance: false)

    # Look for both exact paths and subpage matches
    exact_path_conditions.or(subpage_condition)
  }
end
