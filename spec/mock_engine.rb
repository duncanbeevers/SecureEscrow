require 'ostruct'

class MockEngine
  SUCCESS = 200

  def initialize extra_config = {}
    config extra_config
  end

  def call env
    [ SUCCESS, {}, [ 'nada' ] ]
  end

  def config extra_config = {}
    @config ||= Config.new.tap do |config|
      config.secure_escrow = {
          secure_domain_name:       'www.example.com',
          secure_domain_protocol:   'https',
          secure_domain_port:       443,
          insecure_domain_name:     'www.example.com',
          insecure_domain_protocol: 'http',
          insecure_domain_port:     80
        }.merge extra_config
    end
  end

  def routes
    @routes ||= Routes.new
  end

  class Config < OpenStruct
  end

  class Routes
    def recognize_path path, options = {}
      {}
    end
  end
end

