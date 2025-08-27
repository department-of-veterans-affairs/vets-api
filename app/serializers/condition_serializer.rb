# frozen_string_literal: true

class ConditionSerializer
  include JSONAPI::Serializer

  def self.serialize(record)
    return {} if record.nil?

    attributes = record.attributes || OpenStruct.new
    {
      id: record.id.to_s,
      date: format_date(attributes.date),
      name: attributes.name.to_s,
      provider: attributes.provider&.to_s&.strip.presence,
      facility: attributes.facility&.to_s&.strip.presence,
      comments: attributes.comments&.to_s&.strip.presence
    }
  end

  def self.format_date(value)
    return nil if value.blank?

    begin
      DateTime.parse(value.to_s).iso8601.sub(/\+00:00$/, 'Z')
    rescue ArgumentError
      value.to_s
    end
  end
  private_class_method :format_date
end
