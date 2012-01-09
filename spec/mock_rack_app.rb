class MockRackApp
  def call env
    [ 200, {}, %w(OK!) ]
  end
end

