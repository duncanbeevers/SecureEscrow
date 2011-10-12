# Register as a Rails engine
# in order to hook into asset pipeline
module SecureEscrow
  begin
    class Engine < ::Rails::Engine
      initializer :extend_routing do |app|
        puts "Now might be a good time to mix in to Rails routing methods"
      end
    end
  rescue NameError
  end
end

