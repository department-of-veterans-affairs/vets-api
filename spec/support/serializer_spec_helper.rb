# frozen_string_literal: true

module SerializerSpecHelper
  def serialize(obj, opts = {})
    serializer_class = opts.delete(:serializer_class) || "#{obj.class.name}Serializer".constantize
    if serializer_class.is_a?(ActiveModel::Serializer)
      serializer_with_ams(serializer_class, obj, opts)
    else
      serializer_with_jsonapi(serializer_class, obj, opts)
    end
  end

  def expect_time_eq(serialized_time, time)
    expect(serialized_time).to eq(time.iso8601(3))
  end

  def serializer_with_ams(serializer_class, obj, opts = {})
    serializer = serializer_class.send(:new, obj, opts)
    adapter = ActiveModelSerializers::Adapter.create(serializer, opts)
    adapter.to_json
  end

  def serializer_with_jsonapi(serializer_class ,obj, opts = {})
    serializer = serializer_class.new(obj, opts)
    serializer.serializable_hash.to_json
  end

end
