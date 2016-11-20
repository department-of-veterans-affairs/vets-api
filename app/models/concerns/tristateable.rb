# frozen_string_literal: true

# Reads a column, bypassing activerecord field accessors, so that we can
# differentiate between nil values and boolean false (by default nils in
# activerecord are converted to false). Naturally, booleans can only hold
# true/false, so these fields should be created as strings.
#
module Tristateable
  extend ActiveSupport::Concern

  TRUTHY = %w(yes true t 1 on).freeze

  class_methods do
    def to_bool(val)
      TRUTHY.include?(val.to_s)
    end
  end

  # Reads the field and interprets the result as nil, false, or true. Note,
  # in Ruby anything that isn't false or nil os true. However, we deviate
  # from that to account for GIBCT truth values (c.f. Truthy)
  #
  def tristate_boolean(field_sym)
    raw = self[field_sym]
    raw.present? ? TRUTHY.include?(raw.try(:downcase)) : nil
  end
end
