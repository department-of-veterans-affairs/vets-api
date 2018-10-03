class TimeOfNeedSerializer < ActiveModel::Serializer

  attribute :burial_activity_type
  attribute :remains_type
  attribute :emblem_code
  attribute :subsequent_indicator
  attribute :liner_type
  attribute :liner_size
  attribute :cremains_type
  attribute :cemetery_type

  def attributes(*args)
    super.compact
  end

end

