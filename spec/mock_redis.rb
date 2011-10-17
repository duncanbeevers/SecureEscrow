class MockRedis
  # Mock-y things
  def clear!
    @values = {}
  end

  # Redis-y things
  def set key, value
    values[key] = value
  end

  def get key
    values[key]
  end

  private
  def values
    @values ||= clear!
  end
end

