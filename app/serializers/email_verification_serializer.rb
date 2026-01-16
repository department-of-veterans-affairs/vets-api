# frozen_string_literal: true

class EmailVerificationSerializer
  include FastJsonapi::ObjectSerializer

  set_type :email_verification
  set_id :id

  RESPONSE_TYPE_ATTRIBUTES = {
    status: %i[needs_verification],
    sent: %i[email_sent template_type],
    verified: %i[verified verified_at]
  }.freeze

  attr_reader :response_type_flags

  def initialize(resource, options = {})
    super(resource, options)
    @response_type_flags = options.slice(:status, :sent, :verified)
  end

  def serializable_hash
    data = super()

    response_type = detect_response_type
    attrs = build_attributes_for(response_type)

    data_node = data[:data] || data['data']

    data_node[:attributes] = attrs if data_node

    data
  end

  private

  def detect_response_type
    return nil unless response_type_flags

    enabled = RESPONSE_TYPE_ATTRIBUTES.keys.select { |key| response_type_flags[key] }

    return enabled.first if enabled.size == 1
    return nil if enabled.empty?

    raise ArgumentError,
          'EmailVerificationSerializer expects exactly one of ' \
          "#{RESPONSE_TYPE_ATTRIBUTES.keys.join(', ')} to be true, got: #{enabled.inspect}"
  end

  def build_attributes_for(response_type)
    return {} unless response_type

    case response_type
    when :status
      {
        needs_verification: @resource.respond_to?(:needs_verification) ? @resource.needs_verification : nil
      }.compact
    when :sent
      {
        email_sent: @resource.respond_to?(:email_sent) ? @resource.email_sent : nil,
        template_type: @resource.respond_to?(:template_type) ? @resource.template_type : nil
      }.compact
    when :verified
      {
        verified: @resource.respond_to?(:verified) ? @resource.verified : nil,
        verified_at: @resource.respond_to?(:verified_at) ? @resource.verified_at : nil
      }.compact
    else
      {}
    end
  end
end
