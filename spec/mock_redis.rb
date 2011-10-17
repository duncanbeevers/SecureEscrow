class MockRedis
  def set key, value
    values[key] = value
  end

  def get key
    values[key]
  end

  def exists key
    values.has_key? key
  end

  private
  def values
    @values ||= {}
  end
end

