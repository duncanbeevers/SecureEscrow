Rails.application.config.middleware.use(
  Rack::Escrow::Middleware,
  Rails.application)

# ================================
# When using with Devise / Warden,
#   we want to wrap their
#   authentication responses
# ================================
#   Rails.application.config.middleware.insert_before(
#     Warden::Manager,
#     Rack::Escrow::Middleware,
#     Rails.application)

