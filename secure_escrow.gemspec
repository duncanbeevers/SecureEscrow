# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "secure_escrow/version"

Gem::Specification.new do |s|
  s.name        = "secure_escrow"
  s.version     = SecureEscrow::VERSION
  s.authors     = ["Duncan Beevers"]
  s.email       = ["duncan@dweebd.com"]
  s.homepage    = ""
  s.summary     = "Secure AJAX-style actions for Rails applications"
  s.description = "SecureEscrow provides a content proxy for Rails applications allowing POSTing to secure actions from insecure domains without full-page refreshes"

  s.rubyforge_project = "secure_escrow"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rspec'
  s.add_runtime_dependency 'redis'
end

