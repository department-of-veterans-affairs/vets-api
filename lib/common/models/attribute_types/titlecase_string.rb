# frozen_string_literal: true

class Common::TitlecaseString < Virtus::Attribute
  def coerce(value)
    value&.downcase&.titlecase if value.present? && value.upcase == value
  end
end
