# frozen_string_literal: true

class Common::TitlecaseString < Virtus::Attribute
  def coerce(value)
    value&.downcase&.titlecase
  end
end
