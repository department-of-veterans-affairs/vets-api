# frozen_string_literal: true

module SerializerSpecHelper
  def serialize(obj, opts = {})
    serializer_class = opts.delete(:serializer_class) || "#{obj.class.name}Serializer".constantize
    serializer = serializer_class.send(:new, obj, opts)
    adapter = ActiveModelSerializers::Adapter.create(serializer, opts)
    adapter.to_json
  end

  def expect_time_eq(serialized_time, time)
    expect(serialized_time).to eq(time.iso8601(3))
  end
end
