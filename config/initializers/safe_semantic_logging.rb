module SafeSemanticLogging
  def error(message = nil, payload = nil, &)
    if payload.is_a?(Hash)
      ex = payload[:exception]
      payload = payload.merge(exception: RuntimeError.new(ex.to_s)) if ex && !ex.respond_to?(:backtrace)
    end
    super
  end
end

Rails.logger.singleton_class.prepend(SafeSemanticLogging)
