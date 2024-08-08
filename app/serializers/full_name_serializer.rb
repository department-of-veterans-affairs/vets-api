# frozen_string_literal: true

class FullNameSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attribute :first do |object|
    object[:first]
  end

  attribute :middle do |object|
    object[:middle]
  end

  attribute :last do |object|
    object[:last]
  end

  attribute :suffix do |object|
    object[:suffix]
  end
end
