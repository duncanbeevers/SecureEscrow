class MockRedis
  def set key, value
    values[key] = value
  end

  def get key
    values[key]
  end

  def values
    @values ||= {}
  end
end

