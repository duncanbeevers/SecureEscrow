class MockRedis
  def setex key, ttl, value
    set key, value
    expire key, ttl
  end

  def set key, value
    values[key] = value
  end

  def get key
    values[key]
  end

  def exists key
    values.has_key? key
  end

  def del key
    values.delete key
  end

  def expire key, ttl
  end

  private
  def values
    @values ||= {}
  end
end

