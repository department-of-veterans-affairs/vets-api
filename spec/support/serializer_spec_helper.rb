module SerializerSpecHelper
  def serialize(obj, opts = {})
    serializer_class = opts.delete(:serializer_class) || "#{obj.class.name}Serializer".constantize
    serializer = serializer_class.send(:new, obj)
    adapter = ActiveModelSerializers::Adapter.create(serializer, opts)
    adapter.to_json
  end
end
