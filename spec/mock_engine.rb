class MockEngine
  SUCCESS = 200

  def call env
    [ SUCCESS, {}, [ 'nada' ] ]
  end
end

