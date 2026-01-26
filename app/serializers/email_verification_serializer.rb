# frozen_string_literal: true

##
# EmailVerificationSerializer - Conditional serializer with three response modes
#
# Modes:
# - status: true   => { needs_verification: bool }
# - sent: true     => { email_sent: bool, template_type: string }
# - verified: true => { verified: bool, verified_at: datetime }
#
# Usage: EmailVerificationSerializer.new(resource, status: true)
# Validation: Exactly one mode flag required, multiple flags raise ArgumentError
#
class EmailVerificationSerializer
  include JSONAPI::Serializer

  set_type :email_verification
  set_id :id

  RESPONSE_TYPE_ATTRIBUTES = {
    status: %i[needs_verification],
    sent: %i[email_sent template_type],
    verified: %i[verified verified_at]
  }.freeze

  attr_reader :response_type_flags

  def initialize(resource, options = {})
    verify_resource!(resource)
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

  def verify_resource!(resource)
    raise ArgumentError, 'Resource cannot be nil' if resource.nil?

    raise ArgumentError, 'Resource must respond to :id method for serialization' unless resource.respond_to?(:id)

    unless email_verification_object?(resource)
      verification_methods = %w[needs_verification email_sent template_type verified verified_at]
      raise ArgumentError,
            'Resource must respond to at least one email verification method: ' \
            "#{verification_methods.join(', ')}"
    end
  end

  def email_verification_object?(resource)
    verification_methods = %w[needs_verification email_sent template_type verified verified_at]
    verification_methods.any? { |method| resource.respond_to?(method) }
  end

  def detect_response_type
    return nil unless response_type_flags

    enabled = RESPONSE_TYPE_ATTRIBUTES.keys.select { |key| response_type_flags[key] == true }

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
      attrs = {}
      attrs[:needs_verification] = @resource.needs_verification if @resource.respond_to?(:needs_verification)
      attrs
    when :sent
      attrs = {}
      attrs[:email_sent] = @resource.email_sent if @resource.respond_to?(:email_sent)
      attrs[:template_type] = @resource.template_type if @resource.respond_to?(:template_type)
      attrs
    when :verified
      attrs = {}
      attrs[:verified] = @resource.verified if @resource.respond_to?(:verified)
      attrs[:verified_at] = @resource.verified_at if @resource.respond_to?(:verified_at)
      attrs
    else
      {}
    end
  end
end
