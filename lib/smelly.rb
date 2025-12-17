# frozen_string_literal: true

class Smelly
  # Should trigger a MissingSafeMethod code smell
  def missing_safe_method! = Rails.logger.debug 'This method is smelly'

  # Should trigger a DuplicateMethodCall code smell
  def dup_meth_calls(user)
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
    user.profile.name
  end

  # Should trigger a NestedIterators code smell
  def nested_iterators(items)
    items.each do |item|
      item.children.each do |child|
        child.each_value do |value|
          process(value)
        end
      end
    end
  end

  # Control param
  def perform(action)
    if action == :create
      create_record
    else
      update_record
    end
  end
end
