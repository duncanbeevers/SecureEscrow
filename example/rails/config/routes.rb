EscrowExample::Application.routes.draw do
  get '/' => 'sessions#new'
end

puts "Loading routes"

